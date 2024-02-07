pragma solidity ^0.8.12;

import {ExPopulusCards} from "./ExPopulusCards.sol";
import {ExPopulusToken} from "./ExPopulusToken.sol";

import "hardhat/console.sol";

contract ExPopulusCardGameLogic {

	enum BattleResultStatus {WIN, LOSE, DRAW}

	struct BattlePair {
		ExPopulusCards.NftData playerCard;
		ExPopulusCards.NftData enemyCard;
	}

	struct BattleDetails {
		bytes32[] rounds;
	}

	event BattleResult(address indexed player, bytes32 indexed battleKey, BattleResultStatus result);


	ExPopulusCards public immutable cards;
	ExPopulusToken public immutable token;

	mapping(address => uint256) public winStreak;
	
	/*
		bytes32 key is keccak(abi.encode({msg.sender || battleTimestamp || winStreak})
			this should be unique for each battle, even if in same block
		rounds is an array of bytes32, each representing the battle data for each round
		round data is stored as follows:
			health, attack and ability are pushed to the data as Least Significant Bits
		This cant overflow because the max value for each of these is uint8 - 8 * 3 = 24 bits per player
	*/
	mapping(bytes32 => bytes32[]) internal battleDetails;


	constructor(ExPopulusCards _cards, ExPopulusToken _token) {
		cards = _cards;
		token = _token;
	}

	function battle(uint256[] calldata tokenIds) external returns (bytes32){
		require(tokenIds.length <= 3, "ExPopulusCardGameLogic: Too many tokens");
		
		ExPopulusCards.NftData[] memory playerDeck = cards.getCardsAndAssertOwnership(tokenIds, msg.sender);

		uint256[] memory enemyTokenIds = _populateEnemyTokenIds(tokenIds);
		ExPopulusCards.NftData[] memory enemyDeck = cards.getCards(enemyTokenIds);
		require(enemyDeck.length == 3, "ExPopulusCardGameLogic: Invalid deck");

		bytes32 battleKey = keccak256(abi.encodePacked(msg.sender, block.timestamp, winStreak[msg.sender]));
		BattleResultStatus battleResult = _battleLogic(battleKey, playerDeck, enemyDeck);

		_processBattleResults(battleResult);
		emit BattleResult(msg.sender, battleKey, battleResult);
		return battleKey;
	}

	function getBattleDetails(bytes32 battleKey) external view returns(bytes32[] memory){
		return battleDetails[battleKey];
	}

	function getBattleKey()external view returns(bytes32){
		return _getBattleKey();
	}

	function _getBattleKey()internal view returns(bytes32){
		return keccak256(abi.encodePacked(msg.sender, block.timestamp, winStreak[msg.sender]));
	}

	function _processBattleResults(BattleResultStatus battleResult) internal {
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

	function _battleLogic(bytes32 battleKey, ExPopulusCards.NftData[] memory playerDeck, ExPopulusCards.NftData[] memory enemyDeck) 
		internal returns(BattleResultStatus){
		uint8 playerDeckIndex = 0;
		uint8 enemyDeckIndex = 0;

		bytes32[] storage _battleDetails = battleDetails[battleKey];

		while(playerDeckIndex < 3 && enemyDeckIndex < 3){
			// record health, attack, and ability of each card by shifting this data as Least Significant Bits
			bytes32 dataThisRound = 0;
			dataThisRound = dataThisRound << 8 | bytes32(uint256(playerDeck[playerDeckIndex].health)); //<< enemyDeck[enemyDeckIndex].health;
			dataThisRound = dataThisRound << playerDeck[playerDeckIndex].attack;// << enemyDeck[enemyDeckIndex].attack;
			dataThisRound = dataThisRound << playerDeck[playerDeckIndex].ability;// << enemyDeck[enemyDeckIndex].ability;

			bool playerGoesFirst = _abilityComparison(playerDeck[playerDeckIndex].ability, enemyDeck[enemyDeckIndex].ability);
			
			// add both abilities to the battle details as Least Significant Bits
			BattlePair memory resultingPair = _basicAttack(BattlePair(playerDeck[playerDeckIndex], enemyDeck[enemyDeckIndex]), playerGoesFirst);
			
			// add the health of the cards to the battle details as Least Significant Bits
			// dataThisRound = dataThisRound << playerDeck[playerDeckIndex].health << enemyDeck[enemyDeckIndex].health;		

			console.log("after battle playerCardHealth: %s", resultingPair.playerCard.health);
			console.log("after battle enemyCardHealth: %s", resultingPair.enemyCard.health);

			// determine if any card died
			if(resultingPair.playerCard.health == 0){
				console.log("player card died");
				playerDeckIndex++;
			}
			if(resultingPair.enemyCard.health == 0){
				console.log("enemy card died");
				enemyDeckIndex++;
			}
			console.log("dataThisRound ---->>>>");
			console.logBytes32(dataThisRound);			
			// add data this round to the battle details
			_battleDetails.push(dataThisRound);
		}

		// determine winner
		// console.log("playerDeckIndex: %s", playerDeckIndex);
		// console.log("enemyDeckIndex: %s", enemyDeckIndex);
		return playerDeckIndex < enemyDeckIndex ? BattleResultStatus.WIN : playerDeckIndex > enemyDeckIndex ? BattleResultStatus.LOSE : BattleResultStatus.DRAW;	
	}

	function _abilityComparison(uint8 playerAbility, uint8 enemyAbility) internal pure returns(bool){
		return playerAbility >= enemyAbility;
	}

	function _basicAttack(BattlePair memory pair, bool playerFirst) internal pure returns(BattlePair memory){
		
		if(playerFirst){
			pair.enemyCard.health  = absDiffOrZero(pair.enemyCard.health , pair.playerCard.attack);
		}
		else{
			pair.playerCard.health  = absDiffOrZero(pair.playerCard.health , pair.enemyCard.attack);
		}
		return pair;
	}

	function absDiffOrZero(uint8 a, uint8 b) internal pure returns(uint8){
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
