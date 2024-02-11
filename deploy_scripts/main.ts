import "../hardhat.config";
import { ethers } from "hardhat";
import { Signer } from "ethers";
import { ExPopulusCardGameLogic, ExPopulusCardGameLogicHarness, ExPopulusCards, ExPopulusToken } from "../typechain";

export interface IDeployContractsOutput {
	exPopulusToken: ExPopulusToken;
	exPopulusCards: ExPopulusCards;
	exPopulusCardGameLogic: ExPopulusCardGameLogic;
	exPopulusCardGameLogicHarness: ExPopulusCardGameLogicHarness;
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

	// deploy harness for testing
	const exPopulusGameLogicHarnessContractFactory = await ethers.getContractFactory("ExPopulusCardGameLogicHarness", creator);
	const exPopulusCardGameLogicHarnessContract = await exPopulusGameLogicHarnessContractFactory.deploy()



	return {
		exPopulusToken: exPopulusTokenContract,
		exPopulusCards: exPopulusCardsContract,
		exPopulusCardGameLogic: exPopulusCardGameLogicContract,
		exPopulusCardGameLogicHarness: exPopulusCardGameLogicHarnessContract
	};
}
