// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.13;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILendingRules} from "./ILendingRules.sol";
import {LendingCrunaPluginBase} from "./LendingCrunaPluginBase.sol";

abstract contract LendingCrunaPlugin is LendingCrunaPluginBase {
  using SafeERC20 for IERC20;
  error InsufficientDepositFee(uint256 requiredFee, uint256 providedFee);
  error InsufficientFunds();
  error TransferFailed();
  error InvalidLendingRulesAddress();
  error NotDepositor(address caller, address expected);
  error TransferToTreasuryFailed();
  error TransferNotCompleted(address assetAddress, uint256 tokenId);
  error LendingRulesNotSet();

  // TRT deploys the LendingRules contract, we need the deployer address who did that.
  // Create a mock of the plugin and set the lendingRules address to the address of the LendingRules contract.

  mapping(address => mapping(uint256 => address)) private _depositedAssets;

  ILendingRules public lendingRules;

  function _nameId() internal view virtual override returns (bytes4) {
    return bytes4(keccak256("LendingCrunaPlugin"));
  }

  function setLendingRules(address _lendingRulesAddress) external {
    if (_lendingRulesAddress == address(0)) {
      revert InvalidLendingRulesAddress();
    }
    lendingRules = ILendingRules(_lendingRulesAddress);
  }

  // Function to handle the deposit of an ERC721 token
  function depositAsset(address assetAddress, uint256 tokenId, address stableCoin) public {
    // Correctly calling getDepositFee to check for special pricing or default fee

    // Check that the rule lendingRules address has been set.
    if (address(lendingRules) == address(0)) {
      revert LendingRulesNotSet();
    }

    uint256 depositFee = lendingRules.getDepositFee(assetAddress);

    // Call the rules contract and check if this stablecoin is supported.

    if (IERC20(stableCoin).balanceOf(msg.sender) < depositFee) {
      revert InsufficientFunds();
    }

    _depositedAssets[assetAddress][tokenId] = msg.sender;
    IERC721(assetAddress).safeTransferFrom(msg.sender, address(this), tokenId);

    // Can add which stablecoin was used also or remove care.
    emit AssetReceived(assetAddress, tokenId, msg.sender);

    if (depositFee > 0) {
      address treasuryWallet = lendingRules.getTreasuryWallet();
      IERC20(stableCoin).safeTransferFrom(msg.sender, treasuryWallet, depositFee);
    }
  }

  function withdrawAsset(address assetAddress, uint256 tokenId) public {
    if (_depositedAssets[assetAddress][tokenId] != msg.sender) {
      revert NotDepositor(msg.sender, _depositedAssets[assetAddress][tokenId]);
    }
    _depositedAssets[assetAddress][tokenId] = address(0);
    emit AssetWithdrawn(assetAddress, tokenId, msg.sender);

    IERC721(assetAddress).safeTransferFrom(address(this), msg.sender, tokenId);
  }

  uint256[50] private __gap; // Reserved space for future upgrades
}
