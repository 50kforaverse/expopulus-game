// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import {ExPopulusCardGameLogic} from "../ExPopulusCardGameLogic.sol";
import {ExPopulusCards} from "../ExPopulusCards.sol";
import {ExPopulusToken} from "../ExPopulusToken.sol";

///@dev test contract to be able to preform finer grain testing of battle logic
contract ExPopulusCardGameLogicHarness is ExPopulusCardGameLogic {

    uint256 public randomSeed;

    constructor() ExPopulusCardGameLogic(ExPopulusCards(address(0)), ExPopulusToken(address(0))) {}

    function battleLogic(bytes32 battleKey, ExPopulusCards.NftData[] memory playerDeck, ExPopulusCards.NftData[] memory enemyDeck, uint8[] memory abilityPriorities) external {
        _battleLogic(battleKey, playerDeck, enemyDeck, abilityPriorities);
    }

    function setRandomSeed(uint256 seed) external {
        randomSeed = seed;
    }

    function _getRandomSeed() internal override view returns (uint256) {
        return randomSeed;
    }
}