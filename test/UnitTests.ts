import hre, { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { Signers } from "../types";
import { expect } from "chai";
import { deployContracts } from "../deploy_scripts/main";
import { ContractTransaction, TransactionReceipt } from "ethers";

describe("Unit tests", function () {

	beforeEach(async function () {
		this.signers = {} as Signers;
		const signers: SignerWithAddress[] = await hre.ethers.getSigners();
		this.signers.creator = signers[0];
		this.signers.testAccount2 = signers[1];
		this.signers.testAccount3 = signers[2];

		this.contracts = await deployContracts();
	})

	async function setUpPlayer1AsWinner() {
		// mint 1 powerful cards for player1 (admin)
		await this.contracts.exPopulusCards.connect(this.signers.creator).
			mintCard(1, this.signers.creator.address, [
				{ attack: 10, health: 100, ability: 1 },
			]);
		// mint 3 cards for testAccount2
		await this.contracts.exPopulusCards.connect(this.signers.creator).
			mintCard(3, this.signers.testAccount2.address, [
				{ attack: 2, health: 2, ability: 1 },
				{ attack: 2, health: 2, ability: 1 },
				{ attack: 2, health: 2, ability: 1 }
			]);

	}

	async function adminCallsBattle() {
		expect(await this.contracts.exPopulusCardGameLogic.connect(this.signers.creator)
			.battle([0]))
			.to.emit(this.contracts.exPopulusCardGameLogic, "BattleResult").withArgs(this.signers.creator.address, 2)
			.and
			.to.emit(this.contracts.exPopulusToken, "Transfer");
	}

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
				to.emit(this.contracts.exPopulusCards, "Transfer")
				.withArgs(0, this.signers.testAccount2.address);

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
		it("allows priority to be set for ability", async function () {
			expect(await this.contracts.exPopulusCards.connect(this.signers.creator).assignPriority(0, 7))
				.to.emit(this.contracts.exPopulusCards, "AbilityPrioritySet").withArgs(0, 7);
		});

		it("does not allow randomer to assign priority", async function () {
			await expect(this.contracts.exPopulusCards.connect(this.signers.testAccount3).
				assignPriority(2, 2)).
				to.be.revertedWithCustomError(this.contracts.exPopulusCards, "NotAuthorized");
		});

		it("does not allow existing priority to be set", async function () {
			await expect(this.contracts.exPopulusCards.connect(this.signers.creator).
				assignPriority(0, 1)).
				to.be.revertedWithCustomError(this.contracts.exPopulusCards, "InvalidAbilityPriority");

			// reassign first and try again (should be successful as now not existing priority)
			await this.contracts.exPopulusCards.connect(this.signers.creator).assignPriority(1, 8);

			expect(await this.contracts.exPopulusCards.connect(this.signers.creator).assignPriority(0, 7))
				.to.emit(this.contracts.exPopulusCards, "AbilityPrioritySet").withArgs(0, 1);

		});
	});

	describe("User Story #3 (Battles & Game Loop)", async function () {
		it("too many tokens battled", async function () {
			await expect(this.contracts.exPopulusCardGameLogic.connect(this.signers.creator)
				.battle([1, 2, 3, 4])).to.be.rejectedWith(this.contracts.exPopulusCardGameLogic, "ExPopulusCardGameLogic: Too many tokens");
		});

		it("player doesnt own tokens to be battled", async function () {
			await setUpPlayer1AsWinner.bind(this)();

			await expect(this.contracts.exPopulusCardGameLogic.connect(this.signers.creator)
				.battle([1, 2])).to.be.revertedWith("ExPopulusCards: Not owner of token");
		});

		it("player 1 wins once", async function () {
			expect(await this.contracts.exPopulusCardGameLogicHarness.connect(this.signers.creator).winStreak(this.signers.creator.address)).to.equal(0);
			await setUpPlayer1AsWinner.bind(this)();
			expect(await this.contracts.exPopulusCardGameLogic.connect(this.signers.creator)
				.battle([0])).to.emit(this.contracts.exPopulusCardGameLogic, "BattleResult").withArgs(this.signers.creator.address, 2);

			// check win streak
			expect(await this.contracts.exPopulusCardGameLogic.connect(this.signers.creator).
				winStreak(this.signers.creator.address)).to.equal(1);
		});

		it("player 1 wins twice with high health card", async function () {
			await setUpPlayer1AsWinner.bind(this)();
			expect(await this.contracts.exPopulusCardGameLogic.connect(this.signers.creator)
				.battle([0])).to.emit(this.contracts.exPopulusCardGameLogic, "BattleResult").withArgs(this.signers.creator.address, 2);

			// check win streak
			expect(await this.contracts.exPopulusCardGameLogic.connect(this.signers.creator).
				winStreak(this.signers.creator.address)).to.equal(1);

			// plays again, wins again
			expect(await this.contracts.exPopulusCardGameLogic.connect(this.signers.creator)
				.battle([0])).to.emit(this.contracts.exPopulusCardGameLogic, "BattleResult").withArgs(this.signers.creator.address, 2);
			// check win streak
			expect(await this.contracts.exPopulusCardGameLogic.connect(this.signers.creator).
				winStreak(this.signers.creator.address)).to.equal(2);
		});

		it("player 1 loses", async function () {
			await setUpPlayer1AsWinner.bind(this)();
			await this.contracts.exPopulusCards.connect(this.signers.creator).mintCard(1, this.signers.creator.address, [{ attack: 1, health: 1, ability: 1 }]);

			expect(await this.contracts.exPopulusCardGameLogic.connect(this.signers.creator)
				.battle([4])).to.emit(this.contracts.exPopulusCardGameLogic, "BattleResult").withArgs(this.signers.creator.address, 2);;
		});
	});

	describe("User Story #4 (Fungible Token & Battle Rewards)", async function () {
		beforeEach(async function () {
			await setUpPlayer1AsWinner.bind(this)();
		});

		it("rewards player with 100 tokens when they win", async function () {
			expect(await this.contracts.exPopulusToken.balanceOf(this.signers.creator.address)).to.equal(0);
			await adminCallsBattle.bind(this)();
			expect(await this.contracts.exPopulusCardGameLogic.connect(this.signers.creator)
				.winStreak(this.signers.creator.address)).to.equal(1);
			// check token balance
			expect(await this.contracts.exPopulusToken.balanceOf(this.signers.creator.address)).to.equal(100);
		});

		it("rewards player with 1000 tokens when they win for the 5th time", async function () {

			for (let i = 0; i < 6; i++) {
				expect(await this.contracts.exPopulusToken.balanceOf(this.signers.creator.address)).to.equal(i * 100);
				await adminCallsBattle.bind(this)();
				expect(await this.contracts.exPopulusCardGameLogic.connect(this.signers.creator)
					.winStreak(this.signers.creator.address)).to.equal(i + 1);
			}
			expect(await this.contracts.exPopulusToken.balanceOf(this.signers.creator.address)).to.equal(500 + 1000);

		});
	});

	describe("User Story #5 (Battle Logs & Historical Lookup)", async function () {

		beforeEach(async function () {
			await setUpPlayer1AsWinner.bind(this)();
		});

		it("admin wins and this is recorded and retrievable", async function () {
			await adminCallsBattle.bind(this)();

			const timestampNow = (await hre.ethers.provider.getBlock("latest")).timestamp;
			const battleKey = await this.contracts.exPopulusCardGameLogic.connect(this.signers.creator)
				.getBattleKey(this.signers.creator.address, timestampNow, 0);

			const battleLogs = await this.contracts.exPopulusCardGameLogic
				.connect(this.signers.creator).getBattleDetails(battleKey);

			expect(battleLogs.length).to.be.greaterThan(0);
		});


		describe("Game logic harness tests", async function () {

			const SHIELD_ABILITY = 0
			const ROULETTE_ABILITY = 1
			const FREEZE_ABILITY = 2

			it("player wins with roulette ability", async function () {
				const nftData1 = {
					attack: 1,
					health: 1,
					ability: ROULETTE_ABILITY
				};
				const nftData2 = {
					attack: 255, // super high health and attack intentionally so it must be the roulette ability that wins
					health: 101,
					ability: FREEZE_ABILITY
				};
				const emptyBytes32 = hre.ethers.zeroPadValue("0x", 32);
				const timestampNow = (await hre.ethers.provider.getBlock("latest")).timestamp;
				const battleKey = await this.contracts.exPopulusCardGameLogic.connect(this.signers.creator)
					.getBattleKey(this.signers.creator.address, timestampNow, 0);

				// 10pc chance of winning with ROUTETTE_ABILITY
				// set this artificially higher for testing using harness
				await this.contracts.exPopulusCardGameLogicHarness.connect(this.signers.creator).setRandomSeed(50);

				expect(await this.contracts.exPopulusCardGameLogicHarness.connect(this.signers.creator).battleLogic(emptyBytes32, [nftData1], [nftData2], [0, 0]))
					.to.emit(this.contracts.exPopulusCardGameLogicHarness, "BattleResult").withArgs(battleKey, this.signers.creator.address, 2);

				const battleLogs = await this.contracts.exPopulusCardGameLogic.connect(this.signers.creator).getBattleDetails(battleKey);
				expect(battleLogs.length).to.be.greaterThan(0);

				//todo assert that the battle logs contain the correct result
			})

			it("player wins with shield ability", async function () {
				const nftData1 = {
					attack: 1,
					health: 1,
					ability: SHIELD_ABILITY
				};
				const nftData2 = {
					attack: 1,
					health: 1,
					ability: FREEZE_ABILITY
				};
				const emptyBytes32 = hre.ethers.zeroPadValue("0x", 32);
				expect(await this.contracts.exPopulusCardGameLogicHarness.connect(this.signers.creator).battleLogic(emptyBytes32, [nftData1], [nftData2], [0, 0]))
					.to.emit(this.contracts.exPopulusCardGameLogicHarness, "BattleResult").withArgs(this.signers.creator.address, 2);

				//todo assert that the battle logs contain the correct result
			})


			it("player wins with freeze ability", async function () {
				const nftData1 = {
					attack: 1,
					health: 2,
					ability: FREEZE_ABILITY
				};
				const nftData2 = {
					attack: 1,
					health: 1,
					ability: FREEZE_ABILITY
				};
				const emptyBytes32 = hre.ethers.zeroPadValue("0x", 32);
				expect(await this.contracts.exPopulusCardGameLogicHarness.connect(this.signers.creator).battleLogic(emptyBytes32, [nftData1], [nftData2], [0, 0]))
					.to.emit(this.contracts.exPopulusCardGameLogicHarness, "BattleResult").withArgs(this.signers.creator.address, 2);;

				//todo assert that the battle logs contain the correct result
			})
		})

	});
});
