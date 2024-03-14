const { expect } = require("chai");
const { ethers } = require("hardhat");
const EthDeployUtils = require("eth-deploy-utils");
const deployUtils = new EthDeployUtils();

const CrunaTestUtils = require("./helpers/CrunaTestUtils");

const { normalize, addr0, bytes4, keccak256, increaseBlockTimestampBy } = require("./helpers");

describe("LendingCrunaPluginMock tests", function () {
  let crunaManagerProxy;
  let crunaVault;
  let factory;
  let usdc;
  let deployer, mayGDeployer, azraDeployer, user1, user2, mayGDepositor, azraGamesDepositor, anotherDepositor;
  let mayGBadge, azraBadge, anotherProjectBadge, lendingRules, treasuryWallet;
  let crunaLendingPluginImplentation, crunaLendingPluginProxy;
  let erc6551Registry, crunaRegistry, crunaGuardian;
  let pluginInstance;

  const threeDaysInSeconds = 3 * 24 * 60 * 60;
  const twoDaysInSeconds = 2 * 24 * 60 * 60;

  before(async function () {
    [deployer, mayGDeployer, azraDeployer, user1, user2, treasuryWallet, mayGDepositor, azraGamesDepositor, anotherDepositor] =
      await ethers.getSigners();
    [erc6551Registry, crunaRegistry, crunaGuardian] = await CrunaTestUtils.deployCanonical(deployer);
  });

  async function initAndDeploy() {
    crunaManagerProxy = await CrunaTestUtils.deployManager(deployer);
    crunaVault = await deployUtils.deploy("SomeProtectedNFT", deployer.address);
    await crunaVault.init(crunaManagerProxy.address, true, true, 1, 0);
    factory = await deployUtils.deployProxy("ProtectedNFTFactory", crunaVault.address);
    await crunaVault.setFactory(factory.address);

    // stablecoin mock
    usdc = await deployUtils.deploy("USDCoin", deployer.address);

    // Deploy the LendingRules contract with an activation fee of 100 and a 3-day minimum lending period
    lendingRules = await deployUtils.deploy("LendingRules", deployer.address, treasuryWallet.address, 100, threeDaysInSeconds);
    // Badges that Depositors can send to the Plugin Address
    mayGBadge = await deployUtils.deploy("MagicBadge", mayGDeployer.address);
    azraBadge = await deployUtils.deploy("CoolBadge", azraDeployer.address);
    anotherProjectBadge = await deployUtils.deploy("SuperTransferableBadge", anotherDepositor.address);

    // deploy Cruna Lending plugin
    crunaLendingPluginImplentation = await deployUtils.deploy("LendingCrunaPluginMock");
    crunaLendingPluginProxy = await deployUtils.deploy("LendingCrunaPluginProxy", crunaLendingPluginImplentation.address);
    crunaLendingPluginProxy = await deployUtils.attach("LendingCrunaPluginMock", crunaLendingPluginProxy.address);

    await usdc.mint(deployer.address, normalize("10000"));
    await usdc.mint(mayGDepositor.address, normalize("1000"));
    await usdc.mint(azraGamesDepositor.address, normalize("1000"));
    await usdc.mint(user1.address, normalize("1000"));
    await usdc.mint(user2.address, normalize("1000"));

    await expect(factory.setPrice(990)).to.emit(factory, "PriceSet").withArgs(990);
    await expect(factory.setStableCoin(usdc.address, true)).to.emit(factory, "StableCoinSet").withArgs(usdc.address, true);

    await expect(lendingRules.setStableCoin(usdc.address, true))
      .to.emit(lendingRules, "StableCoinSet")
      .withArgs(usdc.address, true);

    await lendingRules.setStableCoin(usdc.address, true);
    const stableCoins = await lendingRules.getStableCoins();
    expect(stableCoins).to.include(usdc.address);
  }

  //here we test the contract
  beforeEach(async function () {
    await initAndDeploy();
  });

  async function buyNFT(token, amount, buyer) {
    let price = await factory.finalPrice(token.address);
    await token.connect(buyer).approve(factory.address, price.mul(amount));
    let nextTokenId = (await crunaVault.nftConf()).nextTokenId;

    await expect(factory.connect(buyer).buy(token.address, amount))
      .to.emit(crunaVault, "Transfer")
      .withArgs(addr0, buyer.address, nextTokenId);

    return nextTokenId;
  }

  async function pluginAndSaveDepositorConfig() {
    let tokenId = await buyNFT(usdc, 1, user1);
    const managerAddress = await crunaVault.managerOf(tokenId);
    const manager = await ethers.getContractAt("CrunaManager", managerAddress);

    await expect(
      manager
        .connect(user1)
        .plug("LendingCrunaPluginMock", crunaLendingPluginProxy.address, false, false, "0x00000000", 0, 0, 0),
    ).to.emit(manager, "PluginStatusChange");

    const nameId = bytes4(keccak256("LendingCrunaPluginMock"));
    const pluginAddress = await manager.pluginAddress(nameId, "0x00000000");
    pluginInstance = await ethers.getContractAt("LendingCrunaPluginMock", pluginAddress);

    await pluginInstance.connect(user1).setLendingRulesAddress(lendingRules.address);
    const lendingRulesAddressSet = await pluginInstance.lendingRulesAddress();
    expect(lendingRulesAddressSet).to.equal(lendingRules.address);

    // Assuming pluginInstance and lendingRules are already defined and set up in your tests
    const lendingRulesAddress = await pluginInstance.lendingRulesAddress();
    expect(lendingRulesAddress).to.equal(lendingRules.address);
  }

  // describe("deployment", function () {
  //   it.only("should deploy everything as expected", async function () {
  //     // test the beforeEach
  //   });
  // });

  describe("LendingRules Treasury check", function () {
    it("Should get the treasury wallet address after it was deployed", async function () {
      expect(await lendingRules.getTreasuryWallet()).to.equal(treasuryWallet.address);
    });
  });

  describe("Testing depositing functionality", async function () {
    it("Buy and Plug then let MayG deposit an NFT", async function () {
      await pluginAndSaveDepositorConfig();

      const tokenId = 1;
      await mayGBadge.connect(mayGDeployer).safeMint(mayGDepositor.address, tokenId);
      expect(await mayGBadge.ownerOf(tokenId)).to.equal(mayGDepositor.address);

      await mayGBadge.connect(mayGDepositor).approve(pluginInstance.address, tokenId);

      // New approach: Check for special deposit fee for the NFT collection, use default if not set
      // const { depositFee, lendingPeriod } = await lendingRules.getSpecialTerms(mayGBadge.address);
      const { depositFee } = await lendingRules.getSpecialTerms(mayGBadge.address);
      expect(depositFee).to.equal(100);

      await usdc.connect(mayGDepositor).approve(pluginInstance.address, depositFee);

      const treasuryWalletUSDCBalanceBefore = await usdc.balanceOf(treasuryWallet.address);

      await expect(pluginInstance.connect(mayGDepositor).depositAsset(mayGBadge.address, tokenId, usdc.address))
        .to.emit(pluginInstance, "AssetReceived")
        .withArgs(mayGBadge.address, tokenId, mayGDepositor.address, threeDaysInSeconds);

      expect(await mayGBadge.ownerOf(tokenId)).to.equal(pluginInstance.address);

      const treasuryWalletUSDCBalanceAfter = await usdc.balanceOf(treasuryWallet.address);
      expect(treasuryWalletUSDCBalanceAfter.sub(treasuryWalletUSDCBalanceBefore)).to.equal(depositFee);

      await expect(pluginInstance.connect(mayGDepositor).withdrawAsset(mayGBadge.address, tokenId)).to.be.revertedWith(
        "WithdrawalNotAllowedYet",
      );
    });
  });

  describe("Testing depositing functionality for Azra with special deposit fee", async function () {
    it("Set special deposit fee for AzraBadge, then deposit and withdraw an NFT", async function () {
      await pluginAndSaveDepositorConfig();
      // Set a special deposit fee for the AzraBadge contract
      await lendingRules.setSpecialDepositFee(azraBadge.address, 50);
      const tokenId = 2; // Assuming a different tokenId for uniqueness
      await azraBadge.connect(azraDeployer).safeMint(azraGamesDepositor.address, tokenId);
      expect(await azraBadge.ownerOf(tokenId)).to.equal(azraGamesDepositor.address);

      await azraBadge.connect(azraGamesDepositor).approve(pluginInstance.address, tokenId);

      // Retrieve the special deposit fee for the AzraBadge collection
      // const depositFee = await lendingRules.getDepositFee(azraBadge.address);
      const { depositFee } = await lendingRules.getSpecialTerms(azraBadge.address);

      await usdc.connect(azraGamesDepositor).approve(pluginInstance.address, depositFee);

      // Get the treasury balance before the deposit, for later.
      const treasuryWalletUSDCBalanceBefore = await usdc.balanceOf(treasuryWallet.address);

      await expect(pluginInstance.connect(azraGamesDepositor).depositAsset(azraBadge.address, tokenId, usdc.address))
        .to.emit(pluginInstance, "AssetReceived")
        .withArgs(azraBadge.address, tokenId, azraGamesDepositor.address, threeDaysInSeconds);

      expect(await azraBadge.ownerOf(tokenId)).to.equal(pluginInstance.address);

      const treasuryWalletUSDCBalanceAfter = await usdc.balanceOf(treasuryWallet.address);
      expect(treasuryWalletUSDCBalanceAfter.sub(treasuryWalletUSDCBalanceBefore)).to.equal(depositFee);

      await expect(pluginInstance.connect(azraGamesDepositor).withdrawAsset(azraBadge.address, tokenId)).to.be.revertedWith(
        "WithdrawalNotAllowedYet",
      );

      // Increase the block timestamp by 2 days and it should still fail
      await increaseBlockTimestampBy(twoDaysInSeconds);
      await expect(pluginInstance.connect(azraGamesDepositor).withdrawAsset(azraBadge.address, tokenId)).to.be.revertedWith(
        "WithdrawalNotAllowedYet",
      );

      // Increase the block timestamp by 2 more day and it should succeed
      await increaseBlockTimestampBy(twoDaysInSeconds);
      await expect(pluginInstance.connect(azraGamesDepositor).withdrawAsset(azraBadge.address, tokenId))
        .to.emit(pluginInstance, "AssetWithdrawn")
        .withArgs(azraBadge.address, tokenId, azraGamesDepositor.address);
    });
  });
});
