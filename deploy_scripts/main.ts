import "../hardhat.config";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { ExPopulusCardGameLogic, ExPopulusCards, ExPopulusToken } from "../typechain";

export interface IDeployContractsOutput {
	exPopulusToken: ExPopulusToken;
	exPopulusCards: ExPopulusCards;
	exPopulusCardGameLogic: ExPopulusCardGameLogic;
}

export interface IConstructorExPopulusCards {
	name: string;
	symbol: string;
}

export interface IConstructorExPopulusCardGameLogic {
	cards: string;
}

export async function deployContracts(): Promise<IDeployContractsOutput> {

	const creator = ((await ethers.getSigners())[0]) as unknown as Signer;

	const exPopulusCardsContractFactory = await ethers.getContractFactory("ExPopulusCards", creator);
	const exPopulusCardsContract = await exPopulusCardsContractFactory.deploy("Card Name", "CARD")


	const exPopulusTokenContractFactory = await ethers.getContractFactory("ExPopulusToken", creator);
	const exPopulusTokenContract = await exPopulusTokenContractFactory.deploy("TestToken", "TEST", 18)

	const exPopulusGameLogicContractFactory = await ethers.getContractFactory("ExPopulusCardGameLogic", creator);
	const exPopulusCardGameLogicContract = await exPopulusGameLogicContractFactory.deploy(exPopulusCardsContract.target as string, exPopulusTokenContract.target as string)

	await exPopulusTokenContract.setLogicContract(exPopulusCardGameLogicContract.target as string)

	return {
		exPopulusToken: exPopulusTokenContract,
		exPopulusCards: exPopulusCardsContract,
		exPopulusCardGameLogic: exPopulusCardGameLogicContract,
	};
}
