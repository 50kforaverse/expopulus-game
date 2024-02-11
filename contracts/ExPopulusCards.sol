pragma solidity ^0.8.13;

import {ERC721A} from "erc721a/contracts/ERC721A.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

///@title ExPopulusCards
///@notice Non-fungible token contract for in-game cards
contract ExPopulusCards is ERC721A, Ownable {

	///@notice Struct representing the data of a card
	struct NftData {
		uint8 attack;
		uint8 health;
		uint8 ability;
	}

	/*********************************** ERRORS ************************************/

	///@notice Error to be thrown when the caller is not authorized to perform an action
	error NotAuthorized();

	///@notice Error to be thrown when the mint parameters are invalid
	error InvalidMintParams();

	///@notice Error to be thrown when the ability priority being set is invalid
	error InvalidAbilityPriority();

	/*********************************** EVENTS ************************************/

	///@notice Event emitted when a minter is added
	event MinterAdded(address indexed minter);

	///@notice Event emitted when the priority of an ability is updated
	event AbilityPriorityUpdated(uint8 indexed ability, uint8 indexed priority);

	/*********************************** STATE VARIABLES ************************************/

	///@notice A mapping of minters
	mapping(address => bool) minters;

	///@notice A mapping of the data of each card
	mapping(uint256 => NftData) public nftData;


	///@notice  A store of the priority of each ability	
	uint8[] public abilityPriorities; // indexed by ability value


	/*********************************** MODIFIERS ************************************/

	modifier canMint(){
		if(!minters[msg.sender]){
			revert NotAuthorized();
		}
		_;
	}

	/*********************************** CONSTRUCTOR ************************************/

	constructor(string memory _name, string memory _symbol) ERC721A(_name, _symbol) Ownable(msg.sender){
		_addMinter(msg.sender);

		_assignPriorty(0, 0);
		_assignPriorty(1, 1);
		_assignPriorty(2, 2);
	}

	/*********************************** EXTERNAL FUNCTIONS ************************************/

	///@notice Function to get the cards and assert that the owner is the same as the one provided
	///@param tokenIds An array of tokenIds representing the cards to get
	///@param owner The address of the owner to assert ownership against
	function getCardsAndAssertOwnership(uint256[] calldata tokenIds, address owner) external view returns(NftData[] memory){
		NftData[] memory deck = new NftData[](tokenIds.length);
		for(uint256 i = 0; i < tokenIds.length; i++){
			require(ownerOf(tokenIds[i]) == owner, "ExPopulusCards: Not owner of token");
			deck[i] = nftData[tokenIds[i]];
		}
		return deck;
	}

	///@notice Function to get the card at given index
	///@param _index The index of the card to get
	function getCards(uint256[] calldata _index) external view returns(NftData[] memory){
		ExPopulusCards.NftData[] memory deck = new ExPopulusCards.NftData[](_index.length);
		for(uint256 i = 0; i < _index.length; i++){
			deck[i] = nftData[_index[i]];
		}
		return deck;
	}
	
	///@notice View function to get the priority of an ability
	///@param _abilities An array of abilities to get the priority of
	function getAbilityPriority(uint8[] calldata _abilities) external view returns(uint8[] memory){
		uint8[] memory _abilityPriorities = new uint8[](_abilities.length);
		for(uint256 i = 0; i < _abilities.length; i++){
			if(_abilities[i] > abilityPriorities.length){
				revert InvalidAbilityPriority();
			}
			
			_abilityPriorities[i] = abilityPriorities[_abilities[i]];
		}
		return _abilityPriorities;
	}

	/*********************************** AUTHORIZED FUNCTIONS ************************************/
	
	///@notice mint cards to an address
	///@param _quantity The quantity of cards to mint
	///@param _to The address to mint the cards to
	///@param _data The data for the cards to mint
	function mintCard(uint256 _quantity, address _to, NftData[] calldata _data) canMint() external {
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

	///@notice adds a minting address
	///@dev onlyOwner can call this function
	///@param _minters An array of addresses to add as minters
	function addMinter(address[] calldata _minters) external onlyOwner {
		for(uint256 i = 0; i < _minters.length; i++){
			_addMinter(_minters[i]);
		}	
	}

	///@notice assign priority to an ability
	///@dev onlyOwner can call this function. Also ensure that the priority is unique before calling this function.
	///@param ability The ability to assign the priority to
	///@param priority The priority value to assign to the ability
	function assignPriority(uint8 ability, uint8 priority) external canMint {
		_assignPriorty(ability, priority);
	}

	/*********************************** INTERNAL FUNCTIONS ************************************/
	
	function _assignPriorty(uint8 ability, uint8 priority) internal{
		// if there is another ability with the same value revert
		for(uint256 i = 0; i < abilityPriorities.length; i++){
			if(abilityPriorities[i] == priority){
				revert InvalidAbilityPriority();
			}
		}
		if(abilityPriorities.length <= ability){
			abilityPriorities.push(priority);
		}else{
			abilityPriorities[ability] = priority;
		}

		emit AbilityPriorityUpdated(ability, priority);
	}


	function _addMinter(address _minter) internal{
		minters[_minter] = true;
		emit MinterAdded(_minter);
	}

	function _checkAbility(NftData calldata _data) internal pure returns(bool){
		return _data.ability < 3;
	}
}
