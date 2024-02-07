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
		if(_quantity != _data.length){
			revert InvalidMintParams();
		}
		
		uint256 startIndex = totalSupply();
		_safeMint(_to, _quantity);
		
		for(uint256 i = 0; i < _quantity; i++){
			require(_checkAbility(_data[i]), "ExPopulusCards: Invalid ability");
			nftData[startIndex + i] = _data[i];
		}
	}

	function getCardsAndAssertOwnership(uint256[] calldata tokenIds, address owner) external view returns(NftData[] memory){
		NftData[] memory deck = new NftData[](tokenIds.length);
		for(uint256 i = 0; i < tokenIds.length; i++){
			require(ownerOf(tokenIds[i]) == owner, "ExPopulusCards: Not owner of token");
			deck[i] = nftData[tokenIds[i]];
		}
		return deck;
	}


	function getCards(uint256[] calldata _index) external view returns(NftData[] memory){
		ExPopulusCards.NftData[] memory deck = new ExPopulusCards.NftData[](_index.length);
		for(uint256 i = 0; i < _index.length; i++){
			deck[i] = nftData[_index[i]];
		}
		return deck;
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
