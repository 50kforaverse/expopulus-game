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

export interface IConstructorArgs {
	exPopulusCardsConstructor: IConstructorExPopulusCards;
	// exPopulusCardGameLogicConstructor: IConstructorExPopulusCardGameLogic;
}

export async function deployContracts(args: IConstructorArgs): Promise<IDeployContractsOutput> {

	const creator = ((await ethers.getSigners())[0]) as unknown as Signer;

	const exPopulusTokenContractFactory = await ethers.getContractFactory("ExPopulusToken", creator);
	console.log("deploying token")
	const exPopulusTokenContract = await exPopulusTokenContractFactory.deploy()

	const exPopulusCardsContractFactory = await ethers.getContractFactory("ExPopulusCards", creator);
	console.log("deploying cards")
	const exPopulusCardsContract = await exPopulusCardsContractFactory.deploy(args.exPopulusCardsConstructor.name,
		args.exPopulusCardsConstructor.symbol)
	console.log("depl;oyed cards at", exPopulusCardsContract.target)

	const exPopulusGameLogicContractFactory = await ethers.getContractFactory("ExPopulusCardGameLogic", creator);
	console.log("deploying game logic")
	const exPopulusCardGameLogicContract = await exPopulusGameLogicContractFactory.deploy(exPopulusCardsContract.target as string)

	return {
		exPopulusToken: exPopulusTokenContract,
		exPopulusCards: exPopulusCardsContract,
		exPopulusCardGameLogic: exPopulusCardGameLogicContract,
	};
}
