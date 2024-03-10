const { expect } = require("chai");
const { ethers } = require("hardhat");
const EthDeployUtils = require("eth-deploy-utils");
const deployUtils = new EthDeployUtils();

const CrunaTestUtils = require("./helpers/CrunaTestUtils");

const { normalize, addr0, getChainId, getTimestamp, bytes4, keccak256 } = require("./helpers");

describe("CrunaLendingPlugin tests", function () {
  let crunaManagerProxy;
  let crunaVault;
  let factory;
  let usdc;
  let deployer, user1, user2, mayGDepositor, azraGamesDepositor, anotherDepositor;
  let mayGBadge, azraBadge, anotherProjectBadge, lendingRules, treasuryWallet;
  let crunaLendingPluginImplentation, crunaLendingPluginProxy;
  let erc6551Registry, crunaRegistry, crunaGuardian;

  before(async function () {
    [deployer, user1, user2, , treasuryWallet, mayGDepositor, azraGamesDepositor, anotherDepositor] = await ethers.getSigners();
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
    mayGBadge = await deployUtils.deploy("MagicBadge", mayGDepositor.address);
    azraBadge = await deployUtils.deploy("CoolBadge", azraGamesDepositor.address);
    anotherProjectBadge = await deployUtils.deploy("SuperTransferableBadge", anotherDepositor.address);

    // deploy Cruna Lending plugin
    crunaLendingPluginImplentation = await deployUtils.deploy("CrunaLendingPlugin", lendingRules.address);
    crunaLendingPluginProxy = await deployUtils.deploy("CrunaLendingPluginProxy", crunaLendingPluginImplentation.address);
    crunaLendingPluginProxy = await deployUtils.attach("CrunaLendingPlugin", crunaLendingPluginProxy.address);

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

  describe("LendingRules contract set and test Initial State", function () {
    it("Should set get the treasury wallet address after it was deployed", async function () {
      expect(await lendingRules.getTreasuryWallet()).to.equal(treasuryWallet.address);
    });

    it("Should set MayG as a depositor and check the fee", async function () {
      await lendingRules.setDepositFee(mayGDepositor.address, 200);
      const depositFee = await lendingRules.getDepositFee(mayGDepositor.address);
      expect(depositFee).to.equal(200);
    });
  });

  describe("should allow user1 to buy a vault and plug the CrunaLendingPlugin", async function () {
    let tokenId = await buyNFT(usdc, 1, user1);
    const managerAddress = await crunaVault.managerOf(tokenId);
    const manager = await ethers.getContractAt("CrunaManager", managerAddress);

    await expect(
      manager.connect(user1).plug("CrunaLendingPlugin", crunaLendingPluginProxy.address, false, false, "0x00000000", 0, 0, 0),
    ).to.emit(manager, "PluginStatusChange");

    // get the plugin address
    const nameId = bytes4(keccak256("CrunaLendingPlugin"));
    const pluginAddress = await manager.pluginAddress(nameId, "0x00000000");
    const plugin = await ethers.getContractAt("CrunaLendingPlugin", pluginAddress);

    let id = 1;
  });
});
