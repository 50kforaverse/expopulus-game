pragma solidity ^0.8.12;

import {ExPopulusCards} from "./ExPopulusCards.sol";

contract ExPopulusCardGameLogic {

	ExPopulusCards public immutable cards;

	mapping(address => uint256) public winStreak;

	constructor(ExPopulusCards _cards) {
		cards = _cards;
	}

	function battle(uint256[] calldata tokenIds) external {
		// assert tokenId length is at most 3
		require(tokenIds.length <= 3, "ExPopulusCardGameLogic: Too many tokens");
		
		// assert msg.sender owns all the tokenIds passed
		// todo - can we check owner call once? and return all nft data in one call?
		for(uint256 i = 0; i < tokenIds.length; i++){
			require(cards.ownerOf(tokenIds[i]) == msg.sender, "ExPopulusCardGameLogic: Not owner of token");
		}

		//An "enemy" deck should be generated for my cards to battle against by picking 3 existing,
		// in-circulation nft ids from the `ExPopulusCards` contract at random. 
		// todo: clarify -- can this be against their own cards?
		// todo: get secure randomness, not block envs
		ExPopulusCards.NftData[] memory enemyDeck = new ExPopulusCards.NftData[](3);
		for(uint256 i = 0; i < 3; i++){
			enemyDeck[i] = cards.getCard(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, i))) % cards.totalSupply());
		}

		// battle logic
		bool win = true; // _battleLogic(tokenIds, enemyDeck);


		// if I win the battle, I want a number incremented to represent my win "streak", which resets to any time I *lose* a battle.
		if(win){
			winStreak[msg.sender]++;
		}
		else{
			winStreak[msg.sender] = 0;
		}
	}


	function _battleLogic(uint256[] calldata tokenIds, ExPopulusCards.NftData[] memory enemyDeck) internal pure returns(bool){
		//todo
	}
}
