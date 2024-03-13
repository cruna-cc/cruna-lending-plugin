const { expect } = require("chai");
const { ethers } = require("hardhat");
const EthDeployUtils = require("eth-deploy-utils");
const deployUtils = new EthDeployUtils();

describe("LendingRules Contract Tests", function () {
  let LendingRules;
  let lendingRules;
  let deployer, treasuryWallet, mayG, azraGames, mayGBadge, azraBadge, anotherDepositor;

  // Calculate 3 days in seconds
  const threeDaysInSeconds = 3 * 24 * 60 * 60;

  before(async function () {
    [deployer, treasuryWallet, mayG, azraGames, anotherDepositor] = await ethers.getSigners();
    LendingRules = await ethers.getContractFactory("LendingRules");
  });

  beforeEach(async function () {
    lendingRules = await LendingRules.deploy(deployer.address, treasuryWallet.address, 100, threeDaysInSeconds);
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
    it("Should revert setTreasuryWallet when called by non-owner", async function () {
      // Attempt to update the treasury wallet by a non-owner account (mayG in this case)
      await expect(lendingRules.connect(mayG).setTreasuryWallet(azraGames.address)).revertedWith("OwnableUnauthorizedAccount");
    });
  });

  describe("Setting and Getting Fees", function () {
    it("Should allow setting and retrieving the default deposit fee", async function () {
      await lendingRules.setDefaultDepositFee(100);
      const fee = await lendingRules.getDepositFee(ethers.constants.AddressZero); // Assuming getDepositFee will return default if no specific NFT contract is passed
      expect(fee).to.equal(100);
    });

    it("Should allow setting and retrieving special deposit fees for an NFT collection", async function () {
      await lendingRules.setSpecialDepositFee(mayGBadge.address, 50);
      const fee = await lendingRules.getDepositFee(mayGBadge.address);
      expect(fee).to.equal(50);
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
