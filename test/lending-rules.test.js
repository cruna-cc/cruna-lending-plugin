const { expect } = require("chai");
const { ethers } = require("hardhat");
const EthDeployUtils = require("eth-deploy-utils");
const deployUtils = new EthDeployUtils();

describe("LendingRules Contract Tests", function () {
  let LendingRules;
  let lendingRules;
  let usdc, usdt;
  let deployer, treasuryWallet, mayG, azraGames, mayGBadge, azraBadge, anotherDepositor;

  // Calculate 3 days in seconds
  const threeDaysInSeconds = 3 * 24 * 60 * 60;
  const twoDaysInSeconds = 2 * 24 * 60 * 60;

  before(async function () {
    [deployer, treasuryWallet, mayG, azraGames, anotherDepositor] = await ethers.getSigners();
    LendingRules = await ethers.getContractFactory("LendingRules");
  });

  beforeEach(async function () {
    usdc = await deployUtils.deploy("USDCoin", deployer.address);
    usdt = await deployUtils.deploy("TetherUSD", deployer.address);

    lendingRules = await LendingRules.deploy(deployer.address, treasuryWallet.address, 100, threeDaysInSeconds);

    // NFT's that Depositors can send to the Plugin Address
    mayGBadge = await deployUtils.deploy("MagicBadge", mayG.address);
    azraBadge = await deployUtils.deploy("CoolBadge", azraGames.address);
  });

  describe("Deployment and Initial State", function () {
    it("Should setStableCoin check it is set then remove it", async function () {
      await lendingRules.setStableCoin(usdc.address, true);
      const stableCoins = await lendingRules.getStableCoins();
      expect(stableCoins).to.include(usdc.address);

      await lendingRules.setStableCoin(usdc.address, false);
      const stableCoinsAfter = await lendingRules.getStableCoins();
      expect(stableCoinsAfter).to.not.include(usdc.address);
    });

    it("Should set the right treasury wallet on deployment", async function () {
      expect(await lendingRules.getTreasuryWallet()).to.equal(treasuryWallet.address);
    });
  });

  describe("Owner-Only Functions", function () {
    it("Should revert setTreasuryWallet when called by non-owner", async function () {
      await expect(lendingRules.connect(mayG).setTreasuryWallet(azraGames.address)).revertedWith("OwnableUnauthorizedAccount");
    });
  });

  describe("Setting and Getting Fees", function () {
    it("Should allow setting and retrieving the default deposit fee", async function () {
      await lendingRules.setDefaultDepositFee(100);
      const fee = await lendingRules.getDefaultDepositFee();
      expect(fee).to.equal(100);
    });

    it("Should allow setting and retrieving special deposit fees for an NFT collection", async function () {
      await lendingRules.setSpecialDepositFee(mayGBadge.address, 50);
      const { depositFee } = await lendingRules.getSpecialTerms(mayGBadge.address);
      expect(depositFee).to.equal(50);
    });
  });

  describe("Set Special Lending Period", function () {
    it("Should set Special Lending terms lending Period", async function () {
      await lendingRules.setSpecialTerms(azraGames.address, 20, twoDaysInSeconds);
      const { depositFee, lendingPeriod } = await lendingRules.getSpecialTerms(azraGames.address);
      expect(depositFee).to.equal(20);
      expect(lendingPeriod).to.equal(twoDaysInSeconds);
    });

    it("Should update lending Period", async function () {
      await lendingRules.setSpecialLendingPeriod(azraGames.address, twoDaysInSeconds);
      const { lendingPeriod } = await lendingRules.getSpecialTerms(azraGames.address);
      expect(lendingPeriod).to.equal(twoDaysInSeconds);
    });

    // it("Should revert when setting the treasury wallet to the zero address", async function () {
    //   await expect(lendingRules.setTreasuryWallet(ethers.constants.AddressZero)).to.be.revertedWith(
    //     "TreasuryWalletZeroAddress",
    //   );
    // });
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
