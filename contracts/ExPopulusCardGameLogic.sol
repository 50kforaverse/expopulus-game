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

	///@notice Struct representing the details of a battle
	struct BattleDetails {
		uint256[] playerTokenIds;
		uint256[] enemyTokenIds;
		bytes32[] rounds;
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
		rounds is an array of bytes32, each representing the battle data for each round
		round data is stored as follows:
			health, attack and ability are pushed to the data as Least Significant Bits
		This wont overflow because the max value for each of these is uint8 - 8 * 3 = 24 bits per player
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

	function _populateEnemyTokenIds(uint256[] memory tokenIds) internal view returns(uint256[] memory){
		uint256[] memory enemyTokenIds = new uint256[](3);
		uint8 fufilledCards = 0;
		uint256 nonce = 0;
		while(fufilledCards < 3){
			// todo: get secure randomness, not block envs
			uint256 randomCardId = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, nonce))) % cards.totalSupply();
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
		uint8 playerDeckIndex = 0;
		uint8 enemyDeckIndex = 0;

		bytes32[] storage _battleDetails = battleDetails[battleKey].rounds;

		uint8 playerDeckLength = uint8(playerDeck.length);
		uint8 enemyDeckLength = uint8(enemyDeck.length);

		while(playerDeckIndex < playerDeckLength && enemyDeckIndex < enemyDeckLength){
			bytes32 dataThisRound = 0;
			dataThisRound = _bitPackBattleDetails(dataThisRound, playerDeck[playerDeckIndex], enemyDeck[enemyDeckIndex]);

			bool playerGoesFirst = _abilityPriorityComparison(abilityPriorities[playerDeckIndex], abilityPriorities[playerDeckLength + enemyDeckIndex]);
			dataThisRound = _bitPackAbilityPriority(dataThisRound, abilityPriorities[playerDeckIndex], abilityPriorities[playerDeckLength + enemyDeckIndex]);

			// add both abilities to the battle details as Least Significant Bits
			BattlePair memory resultingPair = _basicAttack(BattlePair(playerDeck[playerDeckIndex], enemyDeck[enemyDeckIndex]), playerGoesFirst);
			
			// add the health of the cards to the battle details as Least Significant Bits
			dataThisRound = _bitPackBattleDetails(dataThisRound, playerDeck[playerDeckIndex], enemyDeck[enemyDeckIndex]);		

			// determine if any card died
			if(resultingPair.playerCard.health == 0){
				playerDeckIndex++;
			}
			if(resultingPair.enemyCard.health == 0){
				enemyDeckIndex++;
			}
			// add data this round to the battle details
			_battleDetails.push(dataThisRound);
		}

		BattleResultStatus resultStatus = playerDeckIndex < enemyDeckIndex ? BattleResultStatus.WIN : playerDeckIndex > enemyDeckIndex ? BattleResultStatus.LOSE : BattleResultStatus.DRAW;	

		return BattleResult(resultStatus, _battleDetails);
	}

	function _bitPackAbilityPriority(bytes32 word, uint8 playerAbility, uint8 enemyAbility) internal pure returns(bytes32){
		return word << 8 | bytes32(uint256(playerAbility)) << 8 | bytes32(uint256(enemyAbility));
	}

	function _bitPackBattleDetails(bytes32 word, ExPopulusCards.NftData memory _player, ExPopulusCards.NftData memory _enemy) internal pure returns(bytes32){
		return word << 8 | bytes32(uint256(_player.health)) << 8 | bytes32(uint256(_enemy.health)) << 8 
		| bytes32(uint256(_player.attack)) << 8 | bytes32(uint256(_enemy.attack)) << 8 
		| bytes32(uint256(_player.ability)) << 8 | bytes32(uint256(_enemy.ability));
	}

	function _abilityPriorityComparison(uint8 playerAbility, uint8 enemyAbility) internal pure returns(bool){
		return playerAbility <= enemyAbility; // lower ability goes first
	}

	function _basicAttack(BattlePair memory pair, bool playerFirst) internal pure returns(BattlePair memory){		
		if(playerFirst){
			pair.enemyCard.health  = _absDiffOrZero(pair.enemyCard.health , pair.playerCard.attack);
		}
		else{
			pair.playerCard.health  = _absDiffOrZero(pair.playerCard.health , pair.enemyCard.attack);
		}
		return pair;
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

}
