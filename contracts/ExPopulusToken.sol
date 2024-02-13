// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

///@title ExPopulusToken
///@notice Fungible token contract for in-game rewards
contract ExPopulusToken is ERC20, Ownable {

	/*********************************** STATE VARIABLES ************************************/

	///@notice Address of logic contract
	address public logicContract;

	/*********************************** MODIFIERS ************************************/

	modifier onlyMinter() {
		require(msg.sender == logicContract || msg.sender == owner(), "ExPopulusToken: Only minter can mint");
		_;
	}

	/*********************************** CONSTRUCTOR ************************************/

	constructor(string memory _name, string memory _symbol, uint8 _decimals)
		ERC20(_name, _symbol, _decimals)
		Ownable(msg.sender)
	{}

	/*********************************** AUTHORIZED FUNCTIONS ************************************/

	///@notice Set logic contract address. Only callable by owner
	///@param _logicContract Address of logic contract
	function setLogicContract(address _logicContract) external onlyOwner() {
		logicContract = _logicContract;
	}

	///@notice Mint tokens
	///@param amount Amount of tokens to mint
	///@param to Address to mint tokens to
	function mintToken(uint256 amount, address to) external onlyMinter() {
		_mint(to, amount);
	}
}
