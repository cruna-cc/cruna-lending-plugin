const { expect } = require("chai");
const { ethers } = require("hardhat");
const EthDeployUtils = require("eth-deploy-utils");
const deployUtils = new EthDeployUtils();

describe("LendingRules Contract Tests", function () {
  let LendingRules;
  let lendingRules;
  let deployer, treasuryWallet, mayG, azraGames, mayGBadge, azraBadge, anotherDepositor;

  before(async function () {
    [deployer, treasuryWallet, mayG, azraGames, anotherDepositor] = await ethers.getSigners();
    LendingRules = await ethers.getContractFactory("LendingRules");
  });

  beforeEach(async function () {
    lendingRules = await LendingRules.deploy(deployer.address, treasuryWallet.address, 100);
    // Badges that Depositors can send to the Plugin Address
    mayGBadge = await deployUtils.deploy("MagicBadge", mayG.address);
    azraBadge = await deployUtils.deploy("CoolBadge", azraGames.address);
  });

  describe("Deployment and Initial State", function () {
    it("Should set the right treasury wallet on deployment", async function () {
      expect(await lendingRules.getTreasuryWallet()).to.equal(treasuryWallet.address);
    });
  });

  describe("Owner-Only Functions", function () {
    it("Should revert setDepositFee when called by non-owner", async function () {
      // Attempt to set fees by a non-owner account (mayG in this case)
      await expect(lendingRules.connect(mayG).setDepositorConfig(azraGames.address, 200, azraGames.address)).revertedWith(
        "OwnableUnauthorizedAccount",
      );
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
    it("Should allow setting and retrieving config for a depositor", async function () {
      await lendingRules.setDepositorConfig(mayG.address, 200, mayGBadge.address);
      const [depositFee, nftContractAddress] = await lendingRules.getDepositorConfig(mayG.address);
      expect(depositFee).to.equal(200);
      expect(nftContractAddress).to.equal(mayGBadge.address);
    });

    it("Should allow setting and retrieving the activation fee", async function () {
      await lendingRules.setActivationFee(100); // Setting activation fee
      const activationFee = await lendingRules.getActivationFee(); // Retrieving activation fee
      expect(activationFee).to.equal(100); // Comparing the activation fee
    });

    // This test correctly tests the behavior you've coded in your smart contract
    it("Should revert when setting fees for zero address depositor", async function () {
      await expect(
        lendingRules.setDepositorConfig(ethers.constants.AddressZero, 100, ethers.constants.AddressZero),
      ).to.be.revertedWith("InvalidAddress");
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
