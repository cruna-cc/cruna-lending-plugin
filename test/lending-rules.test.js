const { expect } = require("chai");
const { ethers } = require("hardhat");

describe.skip("LendingRules Contract Tests", function () {
  let LendingRules;
  let lendingRules;
  let deployer, treasuryWallet, mayG, azraGames, anotherDepositor;

  before(async function () {
    [deployer, treasuryWallet, mayG, azraGames, anotherDepositor] = await ethers.getSigners();
    LendingRules = await ethers.getContractFactory("LendingRules");
  });

  beforeEach(async function () {
    lendingRules = await LendingRules.deploy(deployer.address, treasuryWallet.address, 100);
  });

  describe("Deployment and Initial State", function () {
    it("Should set the right treasury wallet on deployment", async function () {
      expect(await lendingRules.getTreasuryWallet()).to.equal(treasuryWallet.address);
    });
  });

  describe("Owner-Only Functions", function () {
    it("Should revert setDepositFee when called by non-owner", async function () {
      // Attempt to set fees by a non-owner account (mayG in this case)
      await expect(lendingRules.connect(mayG).setDepositFee(azraGames.address, 200)).revertedWith("OwnableUnauthorizedAccount");
    });

    it("Should revert setActivationFee when called by non-owner", async function () {
      // Attempt to set fees by a non-owner account (mayG in this case)
      await expect(lendingRules.connect(mayG).setActivationFee(100)).revertedWith("OwnableUnauthorizedAccount");
    });

    it("Should revert setTreasuryWallet when called by non-owner", async function () {
      // Attempt to update the treasury wallet by a non-owner account (mayG in this case)
      await expect(lendingRules.connect(mayG).setTreasuryWallet(azraGames.address)).revertedWith("OwnableUnauthorizedAccount");
    });
  });

  describe("Setting and Getting Fees", function () {
    it("Should allow setting and retrieving fees for a depositor", async function () {
      await lendingRules.setDepositFee(mayG.address, 200);
      const depositFee = await lendingRules.getDepositFee(mayG.address); // This returns a uint256 directly
      expect(depositFee).to.equal(200); // Corrected to directly compare the uint256 value
    });

    it("Should allow setting and retrieving the activation fee", async function () {
      await lendingRules.setActivationFee(100); // Setting activation fee
      const activationFee = await lendingRules.getActivationFee(); // Retrieving activation fee
      expect(activationFee).to.equal(100); // Comparing the activation fee
    });

    // This test correctly tests the behavior you've coded in your smart contract
    it("Should revert when setting fees for zero address depositor", async function () {
      await expect(lendingRules.setDepositFee(ethers.constants.AddressZero, 100)).to.be.revertedWith("InvalidAddress");
    });
  });

  describe("Updating Treasury Wallet", function () {
    it("Should update the treasury wallet address", async function () {
      await lendingRules.setTreasuryWallet(azraGames.address);
      expect(await lendingRules.getTreasuryWallet()).to.equal(azraGames.address);
    });

    it("Should revert when setting the treasury wallet to the zero address", async function () {
      await expect(lendingRules.setTreasuryWallet(ethers.constants.AddressZero)).to.be.revertedWith(
        "TreasuryWalletZeroAddress",
      );
    });
  });
});
