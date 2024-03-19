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

import {console} from "hardhat/console.sol";

contract LendingCrunaPlugin is LendingCrunaPluginBase, IERC7531 {
  using SafeERC20 for IERC20;

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

  event AssetTransferredToPlugin(
    address indexed assetAddress,
    uint256 indexed tokenId_,
    address fromDepositor,
    uint256 indexed toVaultTokenId
  );

  event AssetReceived(address indexed assetAddress, uint256 indexed tokenId, address depositor, uint256 lendingPeriod);

  struct DepositDetail {
    address depositor;
    uint256 withdrawableAfter;
  }

  mapping(address => mapping(uint256 => DepositDetail)) private _depositedAssets;

  ILendingRules public lendingRulesAddress;

  function _nameId() internal view virtual override returns (bytes4) {
    return bytes4(keccak256("LendingCrunaPlugin"));
  }

  function rightsHolderOf(address tokenAddress, uint256 tokenId, bytes4 /* rights */) external view override returns (address) {
    DepositDetail memory depositDetail = _depositedAssets[tokenAddress][tokenId];

    if (depositDetail.depositor == address(0)) {
      revert TokenNotDeposited(tokenAddress, tokenId);
    }

    // Assuming the depositor holds all rights for simplicity; adjust as needed.
    return depositDetail.depositor;
  }

  /*
   * @notice Function to set the lending rules contract address.
   * @param _lendingRulesAddress The address of the lending rules contract.
   */
  function setLendingRulesAddress(address _lendingRulesAddress) external onlyTokenOwner {
    if (_lendingRulesAddress == address(0)) {
      revert InvalidLendingRulesAddress();
    }
    lendingRulesAddress = ILendingRules(_lendingRulesAddress);
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

  function _handleNFTDeposit(address assetAddress, uint256 tokenId, address depositor) internal {
    (, uint256 lendingPeriod) = lendingRulesAddress.getSpecialTerms(assetAddress);

    _depositedAssets[assetAddress][tokenId] = DepositDetail(depositor, block.timestamp + lendingPeriod);

    IERC721(assetAddress).safeTransferFrom(depositor, address(this), tokenId);
    emit AssetReceived(assetAddress, tokenId, depositor, lendingPeriod);
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

  // asstAddress is the MayGBadge, tokenId is the tokenId of the NFT,
  // fromVaultTokenId is the tokenId of the vault that the NFT is currently in, stableCoin is the stablecoin that the deposit fee is paid in
  function depositFromPlugin(address assetAddress, uint256 tokenId, uint256 fromVaultTokenId) external {
    console.log("depositFromPlugin called");

    address fromPlugin = _calculatePluginAddress(fromVaultTokenId);
    console.log("fromPlugin: ", fromPlugin);
    if (fromPlugin != msg.sender) {
      revert InvalidSourcePlugin();
    }

    // Handle the NFT deposit directly, bypassing additional deposit fee handling
    // as the depositFee is paid in withdrawAssetToPlugin function.
    _handleNFTDeposit(assetAddress, tokenId, msg.sender);
  }

  modifier canWithdraw(address assetAddress, uint256 tokenId) {
    console.log("canWithdraw called");
    DepositDetail storage depositDetail = _depositedAssets[assetAddress][tokenId];
    if (depositDetail.depositor != msg.sender) {
      revert NotDepositor(msg.sender, depositDetail.depositor);
    }
    if (block.timestamp < depositDetail.withdrawableAfter) {
      revert WithdrawalNotAllowedYet(block.timestamp, depositDetail.withdrawableAfter);
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
        address(Canonical.crunaRegistry()),
        ERC6551AccountLib.implementation(),
        0x00,
        block.chainid,
        tokenAddress(),
        tokenId
      );
  }

  // rename to transferAssetToPlugin
  // Take the depositFee here and create a common function that is used here and by depositAsset
  function transferAssetToPlugin(
    address assetAddress,
    uint256 tokenId_,
    uint256 toVaultTokenId,
    address stableCoin
  ) public canWithdraw(assetAddress, tokenId_) {
    console.log("transferAssetToPlugin called");
    address toPlugin = _calculatePluginAddress(toVaultTokenId);
    console.log("toPlugin: ", toPlugin);
    // Ensure the target plugin exists by checking the code size
    uint256 size;
    // solhint-disable-next-line no-inline-assembly
    assembly {
      size := extcodesize(toPlugin)
    }
    if (size == 0) revert PluginNotDeployed();

    // Handle the deposit fee for the transfer to ensure the depositor has enough funds
    // and pays the fee to the treasury. This action mirrors fee handling in a deposit context,
    // but it's adapted for transferring between plugins.
    _handleDepositFee(assetAddress, stableCoin, msg.sender);

    // After the deposit fee is handled, initiate the deposit process on the target plugin
    // with the NFT. This action effectively transfers the NFT to the new plugin and deposits it under new terms.
    LendingCrunaPlugin(toPlugin).depositFromPlugin(assetAddress, tokenId_, tokenId());

    // Successfully transferred and deposited NFT under new terms, so clear it from the original depositor's records.
    delete _depositedAssets[assetAddress][tokenId_];

    // Emit an event for the successful transfer and new deposit.
    emit AssetTransferredToPlugin(assetAddress, tokenId_, msg.sender, toVaultTokenId);
  }

  uint256[50] private __gap; // Reserved space for future upgrades
}
