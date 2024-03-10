const { expect } = require("chai");
const { ethers } = require("hardhat");
const EthDeployUtils = require("eth-deploy-utils");
const deployUtils = new EthDeployUtils();

const CrunaTestUtils = require("./helpers/CrunaTestUtils");

const { normalize, addr0, getChainId, getTimestamp, bytes4, keccak256 } = require("./helpers");

describe("LendingCrunaPlugin tests", function () {
  let crunaManagerProxy;
  let crunaVault;
  let factory;
  let usdc;
  let deployer, mayGDeployer, azraDeployer, user1, user2, mayGDepositor, azraGamesDepositor, anotherDepositor;
  let mayGBadge, azraBadge, anotherProjectBadge, lendingRules, treasuryWallet;
  let crunaLendingPluginImplentation, crunaLendingPluginProxy;
  let erc6551Registry, crunaRegistry, crunaGuardian;
  let pluginInstance;

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

    // Deploy the LendingRules contract with an activation fee of 100
    lendingRules = await deployUtils.deploy("LendingRules", deployer.address, treasuryWallet.address, 100);

    // Badges that Depositors can send to the Plugin Address
    mayGBadge = await deployUtils.deploy("MagicBadge", mayGDeployer.address);
    azraBadge = await deployUtils.deploy("CoolBadge", azraDeployer.address);
    anotherProjectBadge = await deployUtils.deploy("SuperTransferableBadge", anotherDepositor.address);

    // deploy Cruna Lending plugin
    crunaLendingPluginImplentation = await deployUtils.deploy("LendingCrunaPlugin");
    crunaLendingPluginProxy = await deployUtils.deploy("LendingCrunaPluginProxy", crunaLendingPluginImplentation.address);
    crunaLendingPluginProxy = await deployUtils.attach("LendingCrunaPlugin", crunaLendingPluginProxy.address);

    await usdc.mint(deployer.address, normalize("10000"));
    await usdc.mint(mayGDepositor.address, normalize("1000"));
    await usdc.mint(azraGamesDepositor.address, normalize("1000"));
    await usdc.mint(user1.address, normalize("1000"));
    await usdc.mint(user2.address, normalize("1000"));

    await expect(factory.setPrice(990)).to.emit(factory, "PriceSet").withArgs(990);
    await expect(factory.setStableCoin(usdc.address, true)).to.emit(factory, "StableCoinSet").withArgs(usdc.address, true);
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
      manager.connect(user1).plug("LendingCrunaPlugin", crunaLendingPluginProxy.address, false, false, "0x00000000", 0, 0, 0),
    ).to.emit(manager, "PluginStatusChange");

    const nameId = bytes4(keccak256("LendingCrunaPlugin"));
    const pluginAddress = await manager.pluginAddress(nameId, "0x00000000");
    pluginInstance = await ethers.getContractAt("LendingCrunaPlugin", pluginAddress);
    await pluginInstance.setLendingRules(lendingRules.address);

    await lendingRules.setDepositorConfig(mayGDepositor.address, 1, mayGBadge.address);
    const [mayGDepositFee, mayGNftContractAddress] = await lendingRules.getDepositorConfig(mayGDepositor.address);
    expect(mayGDepositFee).to.equal(1);
    expect(mayGNftContractAddress).to.equal(mayGBadge.address);

    await lendingRules.setDepositorConfig(azraGamesDepositor.address, 2, azraBadge.address);
    const [azraDepositFee, azraNftContractAddress] = await lendingRules.getDepositorConfig(azraGamesDepositor.address);
    expect(azraDepositFee).to.equal(2);
    expect(azraNftContractAddress).to.equal(azraBadge.address);
  }

  describe("LendingRules Treasury check", function () {
    it("Should get the treasury wallet address after it was deployed", async function () {
      expect(await lendingRules.getTreasuryWallet()).to.equal(treasuryWallet.address);
    });
  });

  describe("Testing depositing functionality", async function () {
    it("Buy and Plug then let MayG deposit an NFT", async function () {
      await pluginAndSaveDepositorConfig();

      // Mint an NFT to mayGDepositor from the mayGBadge contract
      const tokenId = 1;
      await mayGBadge.connect(mayGDeployer).safeMint(mayGDepositor.address, tokenId);

      // Verify mayGDepositor now owns the NFT
      expect(await mayGBadge.ownerOf(tokenId)).to.equal(mayGDepositor.address);

      // mayGDepositor approves the plugin to transfer their NFT
      await mayGBadge.connect(mayGDepositor).approve(pluginInstance.address, tokenId);

      // Define deposit fee and prepare USDC for deposit fee payment
      const [depositFee] = await lendingRules.getDepositorConfig(mayGDepositor.address);
      // Assuming depositFee already in the correct units for USDC (since normalize("1000") was used)

      // mayGDepositor approves the plugin to spend USDC for the deposit fee
      await usdc.connect(mayGDepositor).approve(pluginInstance.address, depositFee);

      // Store treasury balance before deposit for comparison
      const treasuryWalletUSDCBalanceBefore = await usdc.balanceOf(treasuryWallet.address);

      // MayG deposits the NFT into the plugin and covers the deposit fee with USDC
      await expect(pluginInstance.connect(mayGDepositor).depositAsset(mayGBadge.address, tokenId, usdc.address))
        .to.emit(pluginInstance, "AssetReceived")
        .withArgs(mayGBadge.address, tokenId, mayGDepositor.address /* The expected timestamp or another argument here */);

      // // Verify the NFT is now owned by the plugin contract
      expect(await mayGBadge.ownerOf(tokenId)).to.equal(pluginInstance.address);

      // // Verify the deposit fee in USDC was transferred to the treasury wallet
      const treasuryWalletUSDCBalanceAfter = await usdc.balanceOf(treasuryWallet.address);
      expect(treasuryWalletUSDCBalanceAfter.sub(treasuryWalletUSDCBalanceBefore)).to.equal(depositFee);

      // Withdraw the NFT from the plugin back to mayGDepositor
      await expect(pluginInstance.connect(mayGDepositor).withdrawAsset(mayGBadge.address, tokenId))
        .to.emit(pluginInstance, "AssetWithdrawn")
        .withArgs(mayGBadge.address, tokenId, mayGDepositor.address);

      // Verify the NFT is now owned by mayGDepositor again
      expect(await mayGBadge.ownerOf(tokenId)).to.equal(mayGDepositor.address);

      // Optionally, if you had a method to check the deposit record, verify it no longer exists or reflects the withdrawal
    });
  });
});
