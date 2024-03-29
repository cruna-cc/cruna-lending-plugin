// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILendingRules} from "./ILendingRules.sol";
import {LendingCrunaPluginBase} from "./LendingCrunaPluginBase.sol";
import {ERC6551AccountLib} from "erc6551/lib/ERC6551AccountLib.sol";
import {Canonical} from "@cruna/protocol/libs/Canonical.sol";
import {IERC7531} from "./IERC7531.sol";

import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {ICrunaPlugin} from "@cruna/protocol/plugins/ICrunaPlugin.sol";
import {Guardian} from "./Guardian.sol";

contract LendingCrunaPlugin is LendingCrunaPluginBase, IERC7531 {
  using SafeERC20 for IERC20;

  Guardian public guardian;
  address private constant _GUARDIAN_SETTER = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

  error NotTheGuardianSetter();
  error GuardianAlreadySet();
  error NotTrustedImplementation();
  error InvalidPluginVersion(uint256 oldVersion, uint256 newVersion);
  error PluginRequiresNewerManager(uint256 requiredVersion);

  error InsufficientFunds();
  error TransferFailed();
  error InvalidLendingRulesAddress();
  error NotDepositor(address caller, address expected);
  error TransferNotCompleted(address assetAddress, uint256 tokenId);
  error LendingRulesNotSet();
  error WithdrawalNotAllowedYet(uint256 requestTime, uint256 requiredTime);
  error UnsupportedStableCoin();
  error InvalidSourcePlugin();
  error PluginNotDeployed();
  error TokenNotDeposited(address tokenAddress, uint256 tokenId);
  error RightsNotHeld(address tokenAddress, uint256 tokenId, bytes4 rights);

  error OnlyDepositorAllowedToRescind();
  error OwnershipAlreadyRescinded();
  error NotPluginOwnerOrOwnershipNotRescinded(address caller, address assetAddress, uint256 tokenId);
  error OwnershipNotRescindedOrAssetAlreadyTransferred();
  error NotVaultOwner();

  event AssetTransferredToPlugin(
    address indexed assetAddress,
    uint256 indexed tokenId_,
    address fromDepositor,
    uint256 indexed toVaultTokenId
  );

  event AssetReceived(address indexed assetAddress, uint256 indexed tokenId, address depositor, uint256 lendingPeriod);
  event OwnershipRescinded(address indexed depositor, address indexed assetAddress, uint256 indexed tokenId);

  struct DepositDetail {
    address depositor;
    uint256 withdrawableAfter;
    bool ownershipRescinded;
    mapping(bytes4 => bool) rights;
  }

  bytes4 private constant RIGHTS_OWNERSHIP = bytes4(keccak256("ownership"));
  bytes4 private constant RIGHTS_USAGE = bytes4(keccak256("usage"));

  mapping(address => mapping(uint256 => DepositDetail)) private _depositedAssets;

  ILendingRules public lendingRulesAddress;

  function _nameId() internal view virtual override returns (bytes4) {
    return bytes4(keccak256("LendingCrunaPlugin"));
  }
  function setGuardian(address guardian_) external {
    if (_msgSender() != _GUARDIAN_SETTER) revert NotTheGuardianSetter();
    if (guardian_ == address(0)) revert ZeroAddress();
    if (address(guardian) != address(0)) revert GuardianAlreadySet();
    guardian = Guardian(guardian_);
  }

  // It is the plugin's responsibility to be sure that the new implementation is trusted
  function upgrade(address implementation_) external virtual {
    if (owner() != _msgSender()) revert NotTheTokenOwner();
    if (implementation_ == address(0)) revert ZeroAddress();
    bool trusted = guardian.trusted(implementation_);
    if (!trusted) revert NotTrustedImplementation();
    ICrunaPlugin impl = ICrunaPlugin(implementation_);
    uint256 version_ = impl.version();
    if (version_ <= _version()) revert InvalidPluginVersion(_version(), version_);
    uint256 requiredVersion = impl.requiresManagerVersion();
    if (_conf.manager.version() < requiredVersion) revert PluginRequiresNewerManager(requiredVersion);
    StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = implementation_;
  }

  function rightsHolderOf(address tokenAddress, uint256 tokenId, bytes4 rights) external view override returns (address) {
    if (_depositedAssets[tokenAddress][tokenId].depositor == address(0)) {
      revert TokenNotDeposited(tokenAddress, tokenId);
    }

    // Check if the requested rights are held for the token.
    bool hasRights = _depositedAssets[tokenAddress][tokenId].rights[rights];
    if (!hasRights) {
      revert RightsNotHeld(tokenAddress, tokenId, rights);
    }

    return address(this);
  }

  function _handleDepositFee(address assetAddress, address stableCoin, address depositor) internal {
    if (!lendingRulesAddress.isStableCoinSupported(stableCoin)) {
      revert UnsupportedStableCoin();
    }

    (uint256 depositFee, ) = lendingRulesAddress.getSpecialTerms(assetAddress);

    if (depositFee > 0) {
      uint256 stableCoinBalance = IERC20(stableCoin).balanceOf(depositor);
      if (stableCoinBalance < depositFee) {
        revert InsufficientFunds();
      }

      address treasuryWallet = lendingRulesAddress.getTreasuryWallet();
      IERC20(stableCoin).safeTransferFrom(depositor, treasuryWallet, depositFee);
    }
  }

  function _updateDepositorDetails(address assetAddress, uint256 tokenId, address depositor) internal returns (uint256) {
    (, uint256 lendingPeriod) = lendingRulesAddress.getSpecialTerms(assetAddress);
    DepositDetail storage depositDetail = _depositedAssets[assetAddress][tokenId];
    depositDetail.depositor = depositor;
    depositDetail.withdrawableAfter = block.timestamp + lendingPeriod;
    depositDetail.rights[RIGHTS_OWNERSHIP] = true; // Setting ownership rights
    depositDetail.rights[RIGHTS_USAGE] = true; // Setting usage rights
    return lendingPeriod;
  }

  function _handleNFTDeposit(address assetAddress, uint256 tokenId, address depositor) internal {
    // Update deposited assets to reflect new ownership including setting the rights.
    uint256 lendingPeriod = _updateDepositorDetails(assetAddress, tokenId, depositor);

    IERC721(assetAddress).safeTransferFrom(depositor, address(this), tokenId);
    emit AssetReceived(assetAddress, tokenId, depositor, lendingPeriod);
    emit RightsHolderChange(assetAddress, tokenId, address(this), bytes4(keccak256("ownership")));
  }

  function setLendingRulesAddress(address _lendingRulesAddress) external onlyTokenOwner {
    if (_lendingRulesAddress == address(0)) {
      revert InvalidLendingRulesAddress();
    }
    lendingRulesAddress = ILendingRules(_lendingRulesAddress);
  }

  function depositAsset(address assetAddress, uint256 tokenId, address stableCoin) public {
    if (address(lendingRulesAddress) == address(0)) {
      revert LendingRulesNotSet();
    }

    // This function will revert if the depositor does not have enough funds to cover the deposit fee.
    _handleDepositFee(assetAddress, stableCoin, msg.sender);

    // Proceed to handle the NFT deposit after ensuring the deposit fee has been successfully handled.
    _handleNFTDeposit(assetAddress, tokenId, msg.sender);
  }

  function depositFromPlugin(address assetAddress, uint256 tokenId, uint256 fromVaultTokenId) external {
    address fromPlugin = _calculatePluginAddress(fromVaultTokenId);
    if (fromPlugin != msg.sender) {
      revert InvalidSourcePlugin();
    }

    // Ensure the asset was transferred correctly.
    if (IERC721(assetAddress).ownerOf(tokenId) != address(this)) {
      revert TransferNotCompleted(assetAddress, tokenId);
    }

    // Update deposited assets to reflect new ownership.
    uint256 lendingPeriod = _updateDepositorDetails(assetAddress, tokenId, address(this));

    // Emit an event indicating receipt of the asset.
    emit AssetReceived(assetAddress, tokenId, address(this), lendingPeriod);
  }

  modifier canWithdraw(address assetAddress, uint256 tokenId) {
    DepositDetail storage depositDetail = _depositedAssets[assetAddress][tokenId];
    if (depositDetail.depositor != msg.sender) {
      revert NotDepositor(msg.sender, depositDetail.depositor);
    }
    if (block.timestamp < depositDetail.withdrawableAfter) {
      revert WithdrawalNotAllowedYet(block.timestamp, depositDetail.withdrawableAfter);
    }
    if (depositDetail.ownershipRescinded) {
      revert OwnershipAlreadyRescinded();
    }
    _;
  }

  function withdrawAsset(address assetAddress, uint256 tokenId, address withdrawTo) public canWithdraw(assetAddress, tokenId) {
    // Remove the asset from the deposited assets mapping.
    delete _depositedAssets[assetAddress][tokenId];

    // If withdrawTo is a zero address send back to depositor, otherwise send to withdrawTo.
    address to = withdrawTo == address(0) ? msg.sender : withdrawTo;

    // Transfer the asset back to the depositor.
    IERC721(assetAddress).safeTransferFrom(address(this), to, tokenId);
  }

  function _calculatePluginAddress(uint256 tokenId) internal view returns (address) {
    return
      ERC6551AccountLib.computeAddress(
        address(Canonical.erc7656Registry()),
        ERC6551AccountLib.implementation(),
        0x00,
        block.chainid,
        tokenAddress(),
        tokenId
      );
  }

  function transferAssetToPlugin(
    address assetAddress,
    uint256 tokenId_,
    uint256 toVaultTokenId,
    address stableCoin
  ) public canWithdraw(assetAddress, tokenId_) {
    address toPlugin = _calculatePluginAddress(toVaultTokenId);

    // Ensure the target plugin exists by checking the code size
    uint256 size;
    assembly {
      size := extcodesize(toPlugin)
    }
    if (size == 0) revert PluginNotDeployed();

    // Handle the deposit fee for the transfer to ensure the depositor has enough funds
    // and pays the fee to the treasury.
    _handleDepositFee(assetAddress, stableCoin, msg.sender);

    // Transfer the NFT directly to the new plugin.
    IERC721(assetAddress).safeTransferFrom(address(this), toPlugin, tokenId_);

    LendingCrunaPlugin(toPlugin).depositFromPlugin(assetAddress, tokenId_, tokenId());

    // Clear the asset from the current plugin's deposited assets mapping.
    delete _depositedAssets[assetAddress][tokenId_];

    // Emit an event indicating that the NFT has been transferred to another plugin.
    emit AssetTransferredToPlugin(assetAddress, tokenId_, msg.sender, toVaultTokenId);

    emit RightsHolderChange(assetAddress, tokenId_, toPlugin, bytes4(keccak256("ownership")));
  }

  // Function to allow the depositor to rescind ownership of the asset
  function rescindOwnership(address assetAddress, uint256 tokenId) external {
    DepositDetail storage detail = _depositedAssets[assetAddress][tokenId];

    if (msg.sender != detail.depositor) {
      revert OnlyDepositorAllowedToRescind();
    }
    if (detail.ownershipRescinded) {
      revert OwnershipAlreadyRescinded();
    }

    detail.ownershipRescinded = true;

    emit OwnershipRescinded(msg.sender, assetAddress, tokenId);
  }

  // Function to allow the plugin owner to claim the asset if ownership has been rescinded
  function transferOwnership(address assetAddress, uint256 tokenId, address newOwner) public {
    // Ensure the caller is the vault owner
    if (_msgSender() != owner()) {
      revert NotVaultOwner();
    }

    DepositDetail storage detail = _depositedAssets[assetAddress][tokenId];

    // Check if ownership has been rescinded and if the asset is still deposited
    if (!detail.ownershipRescinded || detail.depositor == address(0)) {
      revert OwnershipNotRescindedOrAssetAlreadyTransferred();
    }

    // Transfer the asset to the new owner
    IERC721(assetAddress).safeTransferFrom(address(this), newOwner, tokenId);

    // Reset the deposited asset's details to prevent further actions
    delete _depositedAssets[assetAddress][tokenId];
  }

  uint256[50] private __gap; // Reserved space for future upgrades
}
