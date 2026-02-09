// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.20;

error AlreadyClaimed();
error AlreadyWhitelisted();
error AmountTooBig();
error AmountTooLow();
error AmountIsZero();
error Blacklisted();

error ExpiredSignature(uint256 deadline);
error SameValue();

error Invalid();
error InvalidInput();
error InvalidToken();
error InvalidName();
error InvalidSigner(address owner);
error InvalidDeadline(uint256 approvalDeadline, uint256 intentDeadline);
error NoOrdersIdsProvided();
error InvalidSymbol();
error StartIndexGreaterThanEndIndex();
error InvalidInputArraysLength();
error InvalidRates();

error NotAuthorized();
error NotClaimableYet();
error NullAddress();
error NullContract();

error OracleNotWorkingNotCurrent();
error OracleNotInitialized();
error OutOfBounds();
error InvalidTimeout();

error RedeemMustNotBePaused();
error RedeemMustBePaused();
error SwapMustNotBePaused();
error SwapMustBePaused();

error StablecoinDepeg();
error DepegThresholdTooHigh();

error BondNotStarted();
error BondFinished();
error BondNotFinished();
error BondEndTimeNotInFuture();

error CliffBiggerThanDuration();

error BeginInPast();
error EndTimeBeforeStartTime();
error StartTimeInPast();
error AlreadyStarted();
error CBRIsTooHigh();
error CBRIsNull();

error CannotDistributeUSD0ToRebasingDTMoreThanOnceADay();
error CannotDistributeUSD0ToAccruingDTMoreThanOnceADay();
error CannotDistributeUSD0ToRevenueSwitchMoreThanOnceAWeek();
error DistributionToRevenueSwitchDisabled();
error DistributionToAccruingDTDisabled();
error DistributionToRebasingDTDisabled();
error MaxDailyAccruingMintAmount();
error MaxDailyRebasingDTMintAmount();
error MaxWeeklyRevSwitchMintAmount();
error MaxRevSwitchMintCapExceeded();
error MaxAccruingMintCapExceeded();
error MaxRebasingDTMintCapExceeded();

error LockDurationIsNotEnabled();
error PositionDoesNotExist();
error TopUpDelayHasPassed();
error PositionIsStillLocked();
error PositionIsNotActive();
error RedeemFeeTooBig();
error TooManyRWA();

error InsufficientUSD0Balance();
error InsufficientUsualSLiquidAllocation();
error CannotReduceAllocation();
error OrderNotActive();
error NotRequester();
error ApprovalFailed();

error AmountExceedBacking();
error InvalidOrderAmount(address account, uint256 amount);

error NullMerkleRoot();
error InvalidProof();

error PercentagesSumNotEqualTo100Percent();
error CannotDistributeUsualMoreThanOnceADay();
error NoOffChainDistributionToApprove();
error NoTokensToClaim();

error InvalidOrderId(uint80 roundId);
error NotOwner();
error InvalidClaimingPeriodStartDate();
error InvalidMaxChargeableTax();
error NotInClaimingPeriod();
error ClaimerHasPaidTax();

error ZeroYieldAmount();
error StartTimeNotInFuture();
error StartTimeBeforePeriodFinish();
error CurrentTimeBeforePeriodFinish();
error EndTimeNotAfterStartTime();
error InsufficientAssetsForYield();
error InsufficientAssets();
error InsufficientSupply();

error NotPermittedToEarlyUnlock();
error OutsideEarlyUnlockTimeframe();
error AirdropVoided();
error FloorPriceTooHigh();
error AmountMustBeGreaterThanZero();
error InsufficientUsd0ppBalance();
error UsualAmountTooLow();
error UsualAmountIsZero();
error FloorPriceNotSet();
error UnwrapCapNotSet();
error AmountTooBigForCap();

error StalePrice();
error InvalidPrice();

error YieldSourceNotFound();
error YieldSourceDataTooOld();
error YieldSourceAlreadyExists();
error MaxDataAgeZero();
error InvalidFeed();
error OffChainDistributionRedirectTimeIntervalNotPassed();
error NoInitiatedRedirectedOffChainDistribution();
error AlreadyInitiatedRedirectedOffChainDistribution();
error AlreadyRedirectedOffChainDistribution();
error NoActiveRedirectedOffChainDistribution();

error InvalidWeeklyInterestBps();
error TreasuryAlreadyExists();
error TreasuryNotFound();
