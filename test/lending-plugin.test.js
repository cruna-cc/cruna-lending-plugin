const { expect } = require("chai");
const { ethers } = require("hardhat");
const EthDeployUtils = require("eth-deploy-utils");
const deployUtils = new EthDeployUtils();

const CrunaTestUtils = require("./helpers/CrunaTestUtils");

const { normalize, addr0, bytes4, keccak256, increaseBlockTimestampBy } = require("./helpers");
const { zeroAddress } = require("ethereumjs-util");

describe("LendingCrunaPluginMock tests", function () {
  let crunaManagerProxy;
  let crunaVault;
  let factory;
  let usdc, usdt;
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
    usdt = await deployUtils.deploy("TetherUSD", deployer.address);

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

    await usdc.mint(deployer.address, normalize("100000"));
    await usdc.mint(mayGDepositor.address, normalize("10000"));
    await usdc.mint(azraGamesDepositor.address, normalize("10000"));
    await usdc.mint(user1.address, normalize("10000"));
    await usdc.mint(user2.address, normalize("10000"));

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
    let ret = [];
    const e = expect(factory.connect(buyer).buy(token.address, amount))
      .to.emit(token, "Transfer")
      .withArgs(buyer.address, factory.address, price.mul(amount));
    for (let i = 0; i < amount; i++) {
      ret.push(nextTokenId.add(i));
      e.to.emit(crunaVault, "Transfer").withArgs(addr0, buyer.address, nextTokenId.add(i));
    }
    await e;
    return ret;
  }

  async function buyVaultPlugAndSaveDepositorConfig(user) {
    let tokenId = (await buyNFT(usdc, 1, user))[0];
    const managerAddress = await crunaVault.managerOf(tokenId);
    const manager = await ethers.getContractAt("CrunaManager", managerAddress);

    await expect(
      manager.connect(user).plug("LendingCrunaPlugin", crunaLendingPluginProxy.address, false, false, "0x00000000", 0, 0, 0),
    ).to.emit(manager, "PluginStatusChange");

    const nameId = bytes4(keccak256("LendingCrunaPlugin"));
    const pluginAddress = await manager.pluginAddress(nameId, "0x00000000");
    pluginInstance = await ethers.getContractAt("LendingCrunaPluginMock", pluginAddress);

    expect(await pluginInstance.nameId()).to.equal(nameId);

    // We will check that the pluginInstance returns false when calling requiresToManageTransfer
    expect(await pluginInstance.requiresToManageTransfer()).to.equal(false);

    await pluginInstance.connect(user).setLendingRulesAddress(lendingRules.address);
    const lendingRulesAddressSet = await pluginInstance.lendingRulesAddress();
    expect(lendingRulesAddressSet).to.equal(lendingRules.address);

    // Assuming pluginInstance and lendingRules are already defined and set up in your tests
    const lendingRulesAddress = await pluginInstance.lendingRulesAddress();
    expect(lendingRulesAddress).to.equal(lendingRules.address);

    tokenId = Number(tokenId);
    return { tokenId, pluginInstance };
  }

  async function mintBadgeAndApproveForDeposit(pluginInstance, badge, deployer, tokenId, depositor, usdc) {
    // Mint the badge NFT
    await badge.connect(deployer).safeMint(depositor.address, tokenId);
    expect(await badge.ownerOf(tokenId)).to.equal(depositor.address);

    // Approve the plugin instance to transfer the NFT on behalf of the depositor
    await badge.connect(depositor).approve(pluginInstance.address, tokenId);

    // Fetch the deposit fee required for this badge
    const { depositFee } = await lendingRules.getSpecialTerms(badge.address);
    await usdc.connect(depositor).approve(pluginInstance.address, Number(depositFee));
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
    it("Buy and Plug then let MayG deposit an NFT and fail on Withdraw attempt", async function () {
      const { tokenId: vaultTokenIdUser1, pluginInstance: pluginInstanceUser1 } =
        await buyVaultPlugAndSaveDepositorConfig(user1);

      // Use vaultTokenIdUser1 for the tokenId of the Badge to keep them the same, why not?
      await mintBadgeAndApproveForDeposit(pluginInstanceUser1, mayGBadge, mayGDeployer, vaultTokenIdUser1, mayGDepositor, usdc);

      // We will store the treasury balance before the deposit, for later.
      const treasuryWalletUSDCBalanceBefore = await usdc.balanceOf(treasuryWallet.address);

      await expect(pluginInstanceUser1.connect(mayGDepositor).depositAsset(mayGBadge.address, vaultTokenIdUser1, usdc.address))
        .to.emit(pluginInstanceUser1, "AssetReceived")
        .withArgs(mayGBadge.address, vaultTokenIdUser1, mayGDepositor.address, threeDaysInSeconds);

      expect(await mayGBadge.ownerOf(vaultTokenIdUser1)).to.equal(pluginInstanceUser1.address);

      const treasuryWalletUSDCBalanceAfter = await usdc.balanceOf(treasuryWallet.address);
      const { depositFee } = await lendingRules.getSpecialTerms(mayGBadge.address);
      expect(treasuryWalletUSDCBalanceAfter.sub(treasuryWalletUSDCBalanceBefore)).to.equal(depositFee);

      await expect(
        pluginInstanceUser1.connect(mayGDepositor).withdrawAsset(mayGBadge.address, vaultTokenIdUser1, zeroAddress()),
      ).to.be.revertedWith("WithdrawalNotAllowedYet");
    });
  });

  describe("Testing depositing with special deposit fee and standard withdrawal", async function () {
    it("Set special deposit fee for AzraBadge, then deposit and withdraw an NFT", async function () {
      const { tokenId: vaultTokenIdUser2, pluginInstance: pluginInstanceUser2 } =
        await buyVaultPlugAndSaveDepositorConfig(user1);
      await mintBadgeAndApproveForDeposit(
        pluginInstanceUser2,
        azraBadge,
        azraDeployer,
        vaultTokenIdUser2,
        azraGamesDepositor,
        usdc,
      );

      // Set a special deposit fee for the AzraBadge contract
      await lendingRules.setSpecialDepositFee(azraBadge.address, 50);

      // Retrieve the special deposit fee for the AzraBadge collection
      const { depositFee } = await lendingRules.getSpecialTerms(azraBadge.address);
      expect(depositFee).to.equal(50);
      await usdc.connect(azraGamesDepositor).approve(pluginInstance.address, depositFee);

      // Get the treasury balance before the deposit, for later.
      const treasuryWalletUSDCBalanceBefore = await usdc.balanceOf(treasuryWallet.address);

      // Try and deposit using TetherUSD, which is not an approved stable coin
      await expect(
        pluginInstance.connect(azraGamesDepositor).depositAsset(azraBadge.address, vaultTokenIdUser2, usdt.address),
      ).to.be.revertedWith("UnsupportedStableCoin");

      // Now deposit with an approved stablecoin, which is usdc
      await expect(pluginInstance.connect(azraGamesDepositor).depositAsset(azraBadge.address, vaultTokenIdUser2, usdc.address))
        .to.emit(pluginInstance, "AssetReceived")
        .withArgs(azraBadge.address, vaultTokenIdUser2, azraGamesDepositor.address, threeDaysInSeconds);

      expect(await azraBadge.ownerOf(vaultTokenIdUser2)).to.equal(pluginInstance.address);

      // Now we check that the treasury balance has increased by the deposit fee
      const treasuryWalletUSDCBalanceAfter = await usdc.balanceOf(treasuryWallet.address);
      expect(treasuryWalletUSDCBalanceAfter.sub(treasuryWalletUSDCBalanceBefore)).is.equal(depositFee);

      await expect(
        pluginInstance.connect(azraGamesDepositor).withdrawAsset(azraBadge.address, vaultTokenIdUser2, zeroAddress()),
      ).to.be.revertedWith("WithdrawalNotAllowedYet");

      // Increase the block timestamp by 2 days and it should still fail
      await increaseBlockTimestampBy(twoDaysInSeconds);
      await expect(
        pluginInstance.connect(azraGamesDepositor).withdrawAsset(azraBadge.address, vaultTokenIdUser2, zeroAddress()),
      ).to.be.revertedWith("WithdrawalNotAllowedYet");

      // Increase the block timestamp by 2 more day and it should succeed
      await increaseBlockTimestampBy(twoDaysInSeconds);
      await expect(
        pluginInstance.connect(azraGamesDepositor).withdrawAsset(azraBadge.address, vaultTokenIdUser2, zeroAddress()),
      )
        .to.emit(azraBadge, "Transfer")
        .withArgs(pluginInstance.address, azraGamesDepositor.address, vaultTokenIdUser2);
    });
  });

  describe("Testing transferAssetToPlugin and depositFromPlugin", async function () {
    it("Deposit and withdraw an NFT to another user's plugin address", async function () {
      const magGBadgeTokenId = 1;

      // call buyVaultPlugAndSaveDepositorConfig for user1 and then mint and approve for deposit
      const { tokenId: vaultTokenIdUser1, pluginInstance: pluginInstanceUser1 } =
        await buyVaultPlugAndSaveDepositorConfig(user1);
      await mintBadgeAndApproveForDeposit(pluginInstanceUser1, mayGBadge, mayGDeployer, magGBadgeTokenId, mayGDepositor, usdc);

      // call buyVaultPlugAndSaveDepositorConfig for user2
      const { tokenId: vaultTokenIdUser2, pluginInstance: pluginInstanceUser2 } =
        await buyVaultPlugAndSaveDepositorConfig(user2);

      // mayG deposits a badge to user1's plugin address
      await expect(pluginInstanceUser1.connect(mayGDepositor).depositAsset(mayGBadge.address, magGBadgeTokenId, usdc.address))
        .to.emit(pluginInstanceUser1, "AssetReceived")
        .withArgs(mayGBadge.address, 1, mayGDepositor.address, threeDaysInSeconds);

      // Validate rights holder before the transfer
      expect(
        await pluginInstanceUser1.rightsHolderOf(mayGBadge.address, magGBadgeTokenId, bytes4(keccak256("ownership"))),
      ).to.equal(pluginInstanceUser1.address);

      // Let's increase the block time by 3 days
      await increaseBlockTimestampBy(threeDaysInSeconds + 1);

      // Fetch the deposit fee required for transferring the asset.
      const { depositFee } = await lendingRules.getSpecialTerms(mayGBadge.address);

      // Approve the plugin instance initiating the transfer (pluginInstanceUser1) to spend the deposit fee amount of USDC on behalf of mayGDepositor.
      await usdc.connect(mayGDepositor).approve(pluginInstanceUser1.address, depositFee);

      // Before we transfer lets that user1's plugin now owns the NFT
      expect(await mayGBadge.ownerOf(magGBadgeTokenId)).to.equal(pluginInstanceUser1.address);

      // Expect the transferAssetToPlugin function to successfully transfer the asset to the new plugin and emit the AssetTransferredToPlugin event.
      await expect(
        pluginInstanceUser1
          .connect(mayGDepositor)
          .transferAssetToPlugin(mayGBadge.address, magGBadgeTokenId, vaultTokenIdUser2, usdc.address),
      )
        .to.emit(pluginInstanceUser1, "AssetTransferredToPlugin")
        .withArgs(mayGBadge.address, magGBadgeTokenId, mayGDepositor.address, vaultTokenIdUser2);

      // Check that user1's plugin no longer owns the NFT
      expect(await mayGBadge.ownerOf(magGBadgeTokenId)).to.not.equal(pluginInstanceUser1.address);

      // Check that user2's plugin now owns the NFT
      expect(await mayGBadge.ownerOf(magGBadgeTokenId)).to.equal(pluginInstanceUser2.address);

      // Validate that the rights holder of the NFT is now user2
      expect(
        await pluginInstanceUser2.rightsHolderOf(mayGBadge.address, magGBadgeTokenId, bytes4(keccak256("ownership"))),
      ).to.equal(pluginInstanceUser2.address);
    });
  });
});
