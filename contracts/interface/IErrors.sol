// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IErrors {

  error AllowanceDecreasedBelowZero(); //                   You cannot decrease the allowance below zero.

  error ApproveFromTheZeroAddress(); //                     Approval cannot be called from the zero address (indeed, how have you??).

  error ApproveToTheZeroAddress(); //                       Approval cannot be given to the zero address.

  error BurnFromTheZeroAddress(); //                        Tokens cannot be burned from the zero address. (Also, how have you called this!?!)

  error BurnExceedsBalance(); //                            The amount you have selected to burn exceeds the addresses balance.

  error CallerIsNotAdminNorBonding();   //                  The caller of this function must match the factory address or be an admin.

  error CannotWithdrawThisToken(); //                       Cannot withdraw the specified token.

  error LiquidityPoolCannotBeAddressZero(); //              Cannot add a liquidity pool from the zero address.

  error LiquidityPoolMustBeAContractAddress(); //           Cannot add a non-contract as a liquidity pool.

  error InitialLiquidityNotYetAdded(); //                   Initial liquidity needs to have been added for this to succedd.

  error InvalidTransferTime(); //                           The transfer time has not arrived, and you need to open the trading pair before you can make a transfer.

  error InsufficientAllowance(); //                         There is not a high enough allowance for this operation.

  error TransferFromZeroAddress(); //                       Cannot transfer from the zero address. Indeed, this surely is impossible, and likely a waste to check??

  error TransferToZeroAddress(); //                         Cannot transfer to the zero address.

  error TransferAmountExceedsBalance(); //                  The transfer amount exceeds the accounts available balance.

  error TransferFailed(); //                                The transfer has failed.

  error MintToZeroAddress(); //                             Cannot mint to the zero address.

  error ProjectBuyTaxExceedsLimit();

  error ProjectSellTaxExceedsLimit();

}
