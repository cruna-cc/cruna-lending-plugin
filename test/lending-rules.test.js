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

  describe("Deployment and Initial State testing", function () {
    it("Should set the right treasury wallet on deployment", async function () {
      expect(await lendingRules.getTreasuryWallet()).to.equal(treasuryWallet.address);
    });

    it("Should revert when non-owner tries to whitelist an NFT contract", async function () {
      // Attempt to whitelist an NFT contract by a non-owner account (mayG in this case)
      await expect(lendingRules.connect(mayG).whitelistNFTContract(azraBadge.address, true)).to.be.revertedWith(
        "OwnableUnauthorizedAccount",
      );
    });
  });

  describe("Whitelisting NFT Contracts", function () {
    it("Should allow whitelisting an NFT contract", async function () {
      await lendingRules.whitelistNFTContract(mayGBadge.address, true);
      expect(await lendingRules.isNFTContractWhitelisted(mayGBadge.address)).to.equal(true);
    });
  });

  describe("Owner-Only Functions", function () {
    it("Should revert setTreasuryWallet when called by non-owner", async function () {
      // Attempt to update the treasury wallet by a non-owner account (mayG in this case)
      await expect(lendingRules.connect(mayG).setTreasuryWallet(azraGames.address)).revertedWith("OwnableUnauthorizedAccount");
    });
  });

  describe("Setting and Getting Fees", function () {
    it("Should allow setting and retrieving the activation fee", async function () {
      await lendingRules.setActivationFee(100);
      const activationFee = await lendingRules.getActivationFee();
      expect(activationFee).to.equal(100);
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
