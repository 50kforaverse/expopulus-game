pragma solidity ^0.8.13;

import {ERC721A} from "erc721a/contracts/ERC721A.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

contract ExPopulusCards is ERC721A, Ownable {

	// enum Ability {SHIELD, ROULETE, FREEZE}

	struct NftData {
		uint8 attack;
		uint8 health;
		uint8 ability;
	}

	error NotAuthorized();
	error InvalidMintParams();

	event MinterAdded(address indexed minter);
	event AbilityPirorityUpdated(uint8 indexed ability, uint8 indexed priority);

	mapping(address => bool) minters;
	mapping(uint256 => NftData) public nftData;
	mapping(uint8 => uint8) public abilityPriority;

	constructor(string memory _name, string memory _symbol) ERC721A(_name, _symbol) Ownable(msg.sender){
		_addMinter(msg.sender);
	}

	modifier canMint(){
		if(!minters[msg.sender]){
			revert NotAuthorized();
		}
		_;
	}


	function mintCard(uint256 _quantity, address _to, NftData[] calldata _data) canMint() external{
		console.log("minting card");
		console.log(_quantity);
		console.log(_data.length);
		if(_quantity != _data.length){
			console.log("reverting");
			revert InvalidMintParams();
		}
		uint256 startIndex = totalSupply();
		_safeMint(_to, _quantity);
		for(uint256 i = 0; i < _quantity; i++){
			console.log("cehcking ability");
			require(_checkAbility(_data[i]), "ExPopulusCards: Invalid ability");
			nftData[startIndex + i] = _data[i];
		}
	}

	function getCard(uint256 _index) external view returns(NftData memory){
		return nftData[_index];
	}


	function addMinter(address[] calldata _minters) external onlyOwner {
		for(uint256 i = 0; i < _minters.length; i++){
			_addMinter(_minters[i]);
		}	
	}

	function assignPriority(uint8 ability, uint8 priority) external canMint {
		// todo: add check that ability assigned to priority is valid

		abilityPriority[ability] = priority;
		emit AbilityPirorityUpdated(ability, priority);
	}

	function _addMinter(address _minter) internal{
		minters[_minter] = true;
		emit MinterAdded(_minter);
	}

	function _checkAbility(NftData calldata _data) internal pure returns(bool){
		return _data.ability < 3;
	}
}
