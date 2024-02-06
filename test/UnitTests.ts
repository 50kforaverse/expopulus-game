import hre from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { Signers } from "../types";
import chai, { expect } from "chai";
// import chaiAsPromised from "chai-as-promised";
import { deployContracts, IConstructorArgs } from "../deploy_scripts/main";

describe("Unit tests", function () {

	before(async function () {
		// chai.should();
		// chai.use(chaiAsPromised);

		// Set up a signer for easy use
		this.signers = {} as Signers;
		const signers: SignerWithAddress[] = await hre.ethers.getSigners();
		this.signers.creator = signers[0];
		this.signers.testAccount2 = signers[1];
		this.signers.testAccount3 = signers[2];
		this.signers.testAccount4 = signers[3];

		// Deploy the contracts
		const constructorArgs: IConstructorArgs = {
			exPopulusCardsConstructor: {
				name: "ExPopulusCards",
				symbol: "EPC"
			},
		};
		console.log("deploying contracts...")
		this.contracts = await deployContracts(constructorArgs);
	})

	describe("User Story #1 (Minting)", async function () {
		const nftData1 = {
			attack: 1,
			health: 1,
			ability: 1
		};
		const invalidAbilityData = {
			attack: 1,
			health: 1,
			ability: 3
		};

		it("Can mint a card to a specific player & verify ownership afterwards", async function () {
			expect(await this.contracts.exPopulusCards.connect(this.signers.creator).
				mintCard(1, this.signers.testAccount2.address, [nftData1])).
				to.emit(this.contracts.exPopulusCards, "Transfer");

			// zero indexed so the first card is 0
			expect(await this.contracts.exPopulusCards.ownerOf(0)).
				to.equal(this.signers.testAccount2.address);
			// check the data
			const { attack, health, ability } = await this.contracts.exPopulusCards.nftData(0);
			const nftDataResult = { attack, health, ability };
			expect(nftDataResult).to.deep.equal(nftData1);
			// mint 2 more cards with the same data
			await this.contracts.exPopulusCards.connect(this.signers.creator).
				mintCard(2, this.signers.testAccount2.address, [nftData1, nftData1]);
		});

		it("should revert when invalid ability", async function () {
			await expect(this.contracts.exPopulusCards.connect(this.signers.creator).
				mintCard(1, this.signers.testAccount2.address, [invalidAbilityData])).
				to.be.revertedWith("ExPopulusCards: Invalid ability");
		});

		it("should revert when invalid length inputs", async function () {
			await expect(this.contracts.exPopulusCards.connect(this.signers.creator).
				mintCard(3, this.signers.testAccount2.address, [invalidAbilityData])).
				to.be.revertedWithCustomError(this.contracts.exPopulusCards, `InvalidMintParams`);
		});

		it("should revert when mint called by randomer", async function () {
			await expect(this.contracts.exPopulusCards.connect(this.signers.testAccount3).
				mintCard(1, this.signers.testAccount2.address, [invalidAbilityData])).
				to.be.revertedWithCustomError(this.contracts.exPopulusCards, "NotAuthorized");
		});

		it("should allow owner to add minter and new minter mints", async function () {
			expect(await this.contracts.exPopulusCards.connect(this.signers.creator).
				addMinter([this.signers.testAccount3.address])).to.emit(this.contracts.exPopulusCards, "MinterAdded").
				withArgs(this.signers.testAccount3.address);

			expect(await this.contracts.exPopulusCards.connect(this.signers.testAccount3).
				mintCard(1, this.signers.testAccount2.address, [nftData1])).to.emit(this.contracts.exPopulusCards, "Transfer");

		});
	});

	describe("User Story #2 (Ability Configuration)", async function () {
		it("allows priority to be se for ability", async function () {
			await this.contracts.exPopulusCards.connect(this.signers.creator).assignPriority(1, 1);
		});

		it("does not allow randomer to assign priority", async function () {
			await expect(this.contracts.exPopulusCards.connect(this.signers.testAccount4).
				assignPriority(2, 2)).
				to.be.revertedWithCustomError(this.contracts.exPopulusCards, "NotAuthorized");
		});
	});


	describe("User Story #3 (Battles & Game Loop)", async function () {
	});

	describe("User Story #4 (Fungible Token & Battle Rewards)", async function () {
	});

	describe("User Story #5 (Battle Logs & Historical Lookup)", async function () {
	});
});
