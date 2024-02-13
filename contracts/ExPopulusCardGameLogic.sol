// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import {ExPopulusCards} from "./ExPopulusCards.sol";
import {ExPopulusToken} from "./ExPopulusToken.sol";

///@title ExPopulusCardGameLogic
///@notice Contract containing the logic for the ExPopulus card game
/// using the ExPopulusCards and ExPopulusToken contracts
contract ExPopulusCardGameLogic {

	///@notice Enum representing the result of a battle
	enum BattleResultStatus {WIN, LOSE, DRAW}

	///@notice Struct representing a pair of cards to be used in a battle
	struct BattlePair {
		ExPopulusCards.NftData playerCard;
		ExPopulusCards.NftData enemyCard;
	}

	///@notice Struct representing the result of a battle
	struct BattleResult {
		BattleResultStatus status;
		bytes32 [] rounds;
	}

	///@notice Struct representing the meta details of a battle
	struct BattleDetails {
		uint256[] playerTokenIds;
		uint256[] enemyTokenIds;
		bytes32[] rounds;
	}

	///@notice Struct representing the details of a battle
	struct BattleRoundInfo {
		AbilityFlags playerAbilityFlags;
		AbilityFlags enemyAbilityFlags;
		uint8 playerDeckIndex;
		uint8 enemyDeckIndex;
		bool firstRound;
	}

	///@notice Struct representing the flags of a abilities
	struct AbilityFlags {
		bool noDamage;
		bool noAttackOrAbility;
		bool endGame;
	}

	/*********************************** EVENTS ************************************/

	///@notice Event emitted when a battle is completed
	event Battle(address indexed player, bytes32 indexed battleKey, uint256[] playerTokenIds, uint256[] enemyTokenIds, BattleResultStatus result);

	/*********************************** STATE VARIABLES ************************************/

	///@notice The ExPopulusCards contract
	ExPopulusCards public immutable cards;

	///@notice  The ExPopulusToken contract
	ExPopulusToken public immutable token;

	///@notice  A mapping of the win streak of each player
	mapping(address => uint32) public winStreak;
	
	///@notice  A mapping of the battle details for each battle
	/** @dev
		bytes32 key is keccak(abi.encode({msg.sender || battleTimestamp || winStreak})
			this should be unique for each battle, even if in same block
		rounds is an array of bytes32, each array entry representing the battle data for each round
		round data is stored as follows:
			1. health, attack and ability are pushed to the data as LSB at 8 bit intervals
			2. ability priority is packed into the next 16 bits for (player, enemy)
			3. ability flags are packed into the next 24 bits for (player, enemy)

		
	*/
	mapping(bytes32 => BattleDetails) internal battleDetails;

	/*********************************** CONSTRUCTOR ************************************/

	constructor(ExPopulusCards _cards, ExPopulusToken _token) {
		cards = _cards;
		token = _token;
	}

	/*********************************** EXTERNAL FUNCTIONS ************************************/

	///@notice Function to initiate a battle
	///@param tokenIds An array of tokenIds representing the cards to be used in the battle
	function battle(uint256[] calldata tokenIds) external returns (bytes32){
		require(tokenIds.length <= 3, "ExPopulusCardGameLogic: Too many tokens");
		
		ExPopulusCards.NftData[] memory playerDeck = cards.getCardsAndAssertOwnership(tokenIds, msg.sender);

		uint256[] memory enemyTokenIds = _populateEnemyTokenIds(tokenIds);
		ExPopulusCards.NftData[] memory enemyDeck = cards.getCards(enemyTokenIds);
		require(enemyDeck.length == 3, "ExPopulusCardGameLogic: Invalid deck");

		// get ability priorities
		uint8[] memory abilityPriorities = new uint8[](tokenIds.length + enemyTokenIds.length);
		abilityPriorities = cards.getAbilityPriority(abilityPriorities);


		bytes32 battleKey = _getBattleKey();
		BattleResult memory battleResult = _battleLogic(battleKey, playerDeck, enemyDeck, abilityPriorities);

		_processBattleRewards(battleResult.status);

		battleDetails[battleKey] = BattleDetails({
			playerTokenIds: tokenIds,
			enemyTokenIds: enemyTokenIds,
			rounds: battleResult.rounds
		});

		emit Battle(msg.sender, battleKey, tokenIds, enemyTokenIds, battleResult.status);
		return battleKey;
	}

	///@notice Function to get the battle details for a given battle
	function getBattleDetails(bytes32 battleKey) external view returns(BattleDetails memory){
		return battleDetails[battleKey];
	}

	///@notice Function to get the battle key for a particular battle
	function getBattleKey(address player, uint64 timestamp, uint256 _winStreak) external pure returns(bytes32){
		return _calculateBattleKey(player, timestamp, _winStreak);
	}

	/*********************************** INTERNAL FUNCTIONS ************************************/

	function _calculateBattleKey(address player, uint64 timestamp, uint256 _winStreak) internal pure returns(bytes32){
		return keccak256(abi.encodePacked(player, timestamp, _winStreak));
	}

	function _getBattleKey()internal view returns(bytes32){
		return _calculateBattleKey(msg.sender, uint64(block.timestamp), winStreak[msg.sender]);
	}

	function _processBattleRewards(BattleResultStatus battleResult) internal {
		uint256 rewardAmount = 0;
		
		if(battleResult == BattleResultStatus.WIN){
			uint256 currentStreak = winStreak[msg.sender];	
			rewardAmount = 100;
			if(currentStreak != 0 && currentStreak % 5 == 0){
				rewardAmount = 1000;
			}
			winStreak[msg.sender]++;
		}
		else if(battleResult == BattleResultStatus.LOSE){
			winStreak[msg.sender] = 0;
		}

		if(rewardAmount > 0){
			token.mintToken(rewardAmount, msg.sender);
		}
	}

	///@dev this function is used to populate the enemy deck with random cards EXCLUDING the player's cards
	function _populateEnemyTokenIds(uint256[] memory tokenIds) internal view returns(uint256[] memory){
		uint256[] memory enemyTokenIds = new uint256[](3);
		uint8 fufilledCards = 0;
		uint256 nonce = 0;
		while(fufilledCards < 3){
			uint256 randomCardId = uint256(keccak256(abi.encode(_getRandomSeed(), nonce))) % cards.totalSupply();
			if(_arrayDoesNotContain(tokenIds, randomCardId)){
				enemyTokenIds[fufilledCards] = randomCardId;
				fufilledCards++;
			}			
			nonce++;
		}
		return enemyTokenIds;
	}

	function _battleLogic(bytes32 battleKey, ExPopulusCards.NftData[] memory playerDeck, ExPopulusCards.NftData[] memory enemyDeck, uint8[] memory abilityPriorities) 
		internal returns(BattleResult memory){
		
		bytes32[] storage _battleRoundDetails = battleDetails[battleKey].rounds;
		
		BattleRoundInfo memory roundInfo;
		roundInfo.firstRound = true;
		bool playerGoesFirst;

		/*
			The battle loop happens in three stages:
			1. Abilities
			2. Basic Attacks
			3. Determine if any card died

			this repeats in a loop until one actor has no more cards in their deck
		*/
		
		while(roundInfo.playerDeckIndex < playerDeck.length && roundInfo.enemyDeckIndex < enemyDeck.length){
			
			bytes32 dataThisRound = _bitPackBattleDetails(0, playerDeck[roundInfo.playerDeckIndex], enemyDeck[roundInfo.enemyDeckIndex]);

			// STAGE 1: abilities only happen on the first round
			if(roundInfo.firstRound){
				playerGoesFirst = _abilityPriorityComparison(abilityPriorities[roundInfo.playerDeckIndex], abilityPriorities[playerDeck.length + roundInfo.enemyDeckIndex]);
				dataThisRound = _bitPackAbilityPriority(dataThisRound, abilityPriorities[roundInfo.playerDeckIndex], abilityPriorities[playerDeck.length + roundInfo.enemyDeckIndex]);

				roundInfo.playerAbilityFlags = _loadAbilityFlags(playerDeck[roundInfo.playerDeckIndex].ability);
				roundInfo.enemyAbilityFlags = _loadAbilityFlags(enemyDeck[roundInfo.enemyDeckIndex].ability);
				dataThisRound = _bitPackAbilityFlags(dataThisRound, roundInfo.playerAbilityFlags, roundInfo.enemyAbilityFlags);
				
				roundInfo.firstRound = false;

				// ROULETTE ABILITY
				if(roundInfo.playerAbilityFlags.endGame || roundInfo.enemyAbilityFlags.endGame){
					if(playerGoesFirst){
						roundInfo.enemyDeckIndex = uint8(enemyDeck.length);
					}
					else{
						roundInfo.playerDeckIndex = uint8(playerDeck.length);
					}
					_battleRoundDetails.push(dataThisRound);	
					break;				
				}

				// SHIELD ABILITY
				// if player card does not have shield ability then enemy card can attack
				if(!roundInfo.playerAbilityFlags.noDamage){
					playerDeck[roundInfo.playerDeckIndex]= _basicAttack(enemyDeck[roundInfo.enemyDeckIndex], playerDeck[roundInfo.playerDeckIndex]);
					_battleRoundDetails.push(dataThisRound);
					continue;
				}
				// if enemy card does not have shield ability then player card can attack
				if(!roundInfo.enemyAbilityFlags.noDamage){
					enemyDeck[roundInfo.enemyDeckIndex] = _basicAttack(playerDeck[roundInfo.playerDeckIndex], enemyDeck[roundInfo.enemyDeckIndex]);
					_battleRoundDetails.push(dataThisRound);
					continue;
				}

				// FREEZE ABILITY
				if(roundInfo.playerAbilityFlags.noAttackOrAbility || roundInfo.enemyAbilityFlags.noAttackOrAbility){
					_battleRoundDetails.push(dataThisRound);
					continue;
				}

			}
				
			// STAGE 2: now process basic attacks
			if(playerGoesFirst){
				playerDeck[roundInfo.playerDeckIndex] = _basicAttack(enemyDeck[roundInfo.enemyDeckIndex], playerDeck[roundInfo.playerDeckIndex]);
				enemyDeck[roundInfo.enemyDeckIndex] = _basicAttack(playerDeck[roundInfo.playerDeckIndex], enemyDeck[roundInfo.enemyDeckIndex]);
			}
			else{
				enemyDeck[roundInfo.enemyDeckIndex] = _basicAttack(playerDeck[roundInfo.playerDeckIndex], enemyDeck[roundInfo.enemyDeckIndex]);
				playerDeck[roundInfo.playerDeckIndex] = _basicAttack(enemyDeck[roundInfo.enemyDeckIndex], playerDeck[roundInfo.playerDeckIndex]);
			}
			
			// record basic attack results
			dataThisRound = _bitPackBattleDetails(dataThisRound, playerDeck[roundInfo.playerDeckIndex], enemyDeck[roundInfo.enemyDeckIndex]);		
			
			// STAGE 3: determine if any card died and process this
			if(playerDeck[roundInfo.playerDeckIndex].health == 0){
				roundInfo.playerDeckIndex++;
				roundInfo.firstRound = true;
			}
			if(enemyDeck[roundInfo.enemyDeckIndex].health == 0){
				roundInfo.enemyDeckIndex++;
				roundInfo.firstRound = true;
			}
			
			// add data this round to the battle details
			_battleRoundDetails.push(dataThisRound);			
		}

		// calculate if winner
		BattleResultStatus resultStatus = roundInfo.playerDeckIndex < roundInfo.enemyDeckIndex ? BattleResultStatus.WIN : roundInfo.playerDeckIndex > roundInfo.enemyDeckIndex ? BattleResultStatus.LOSE : BattleResultStatus.DRAW;	
		
		return BattleResult(resultStatus, _battleRoundDetails);
	}

	function _loadAbilityFlags(uint8 ability) internal view returns(AbilityFlags memory){
		// apply abilty logic
		/*
			1. <b>Shield (Ability 0)</b>: Protects the casting card from any incoming damage or the effects of the freeze ability for the current turn
			2. <b>Roulette (Ability 1)</b>: The casting card has a 10% chance to instantly end the game (by killing all opposite deck cards & bypassing the opposite card's "shield", if any) 
			in its team's favor resulting in a win for the team. 
			3. <b>Freeze (Ability 2)</b>: Prevents the other deck's front card from performing any abilities or basic attack for the rest of the turn.
		*/
		bool noDamage = false;
		bool noAttackOrAbility = false;
		bool endGame = false;
		if(ability == 0){
			noDamage = true;
		}
		if(ability == 1){
			uint256 random = _getRandomSeed() % 100;
			if(random < 10){
				endGame = true;
			}
		}
		if(ability == 2){
			noAttackOrAbility = true;
		}
		return AbilityFlags(noDamage, noAttackOrAbility, endGame);
	}

	function _bitPackAbilityPriority(bytes32 word, uint8 playerAbility, uint8 enemyAbility) internal pure returns(bytes32){
		return word << 8 | bytes32(uint256(playerAbility)) << 8 | bytes32(uint256(enemyAbility));
	}

	function _bitPackAbilityFlags(bytes32 word, AbilityFlags memory playerAbility, AbilityFlags memory enemyAbility) internal pure returns(bytes32){
		return word << 8 | toBytes32(playerAbility.noDamage) << 8 | toBytes32(playerAbility.noAttackOrAbility) << 8 | toBytes32(playerAbility.endGame) << 8
		| toBytes32(enemyAbility.noDamage) << 8 | toBytes32(enemyAbility.noAttackOrAbility) << 8 | toBytes32(enemyAbility.endGame);
	}

	function _bitPackBattleDetails(bytes32 word, ExPopulusCards.NftData memory _player, ExPopulusCards.NftData memory _enemy) internal pure returns(bytes32){
		return word << 8 | bytes32(uint256(_player.health)) << 8 | bytes32(uint256(_enemy.health)) << 8 
		| bytes32(uint256(_player.attack)) << 8 | bytes32(uint256(_enemy.attack)) << 8 
		| bytes32(uint256(_player.ability)) << 8 | bytes32(uint256(_enemy.ability));
	}

	function _abilityPriorityComparison(uint8 playerAbility, uint8 enemyAbility) internal pure returns(bool){
		return playerAbility <= enemyAbility; // lower ability goes first
	}

	function _getRandomSeed() internal virtual view returns(uint256){
		// todo: get secure randomness, not block envs
		return uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao)));
	}

	function _basicAttack(ExPopulusCards.NftData memory attacker, ExPopulusCards.NftData memory defender) internal pure returns(ExPopulusCards.NftData memory){			
		uint8 newHealth =  _absDiffOrZero(defender.health , attacker.attack);
		return ExPopulusCards.NftData(newHealth, defender.attack, defender.ability);
	}

	function _absDiffOrZero(uint8 a, uint8 b) internal pure returns(uint8){
		return a > b ? a - b : 0;
	}

	function _arrayDoesNotContain(uint256[] memory array, uint256 value) internal pure returns(bool){
		for(uint256 i = 0; i < array.length; i++){
			if(array[i] == value){
				return false;
			}
		}
		return true;
	}

	function toBytes32(bool x) private pure returns (bytes32 r) {
         assembly { r := x }
    }
}
