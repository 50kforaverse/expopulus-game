pragma solidity ^0.8.12;

import {ExPopulusCardGameLogic} from "../ExPopulusCardGameLogic.sol";
import {ExPopulusCards} from "../ExPopulusCards.sol";
import {ExPopulusToken} from "../ExPopulusToken.sol";

import "hardhat/console.sol";


contract ExPopulusCardGameLogicHarness is ExPopulusCardGameLogic {

    constructor() ExPopulusCardGameLogic(ExPopulusCards(address(0)), ExPopulusToken(address(0))) {}

    function battleLogic(bytes32 battleKey, ExPopulusCards.NftData[] memory playerDeck, ExPopulusCards.NftData[] memory enemyDeck, uint8[] memory abilityPriorities) external {
        _battleLogic(battleKey, playerDeck, enemyDeck, abilityPriorities);
    }

}