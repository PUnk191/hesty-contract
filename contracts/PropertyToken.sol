// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/access/IAccessControlDefaultAdminRules.sol";
import "./interfaces/IHestyAccessControl.sol";

/**
 * @title   Property Token
 *
 * @notice  Token associated to a property that tracks
            investors and stakeholders that are entitled
            to a share of the property generated revenue.
 *
 * @dev     {ERC20} token, including:
 *
 *          - Pre minted initial supply
 *          - Ability for holders to burn (destroy) their tokens
 *          - No access control mechanism (for minting/pausing) and hence no governance
 *
 *
 * @author Pedro G. S. Ferreira
 */
contract PropertyToken is ERC20Pausable, IAccessControl, IAccessControlDefaultAdminRules{

    uint256 private constant    BASIS_POINTS = 10000;       /// @notice BASIS POINTS used for % math calculations
    uint32  private constant    MULTIPLIER   = 1e9;         /// @notice Multiplier to guarantee math safety in gwei, everything else is neglectable
    uint256 public              dividendPerToken;           /// @notice Dividends per share/token
    mapping(address => uint256) public xDividendPerToken;   /// @notice Last user dividends essential to calculate future rewards

    address public ctrHestyControl;
    IERC20  public rewardAsset;

    bytes32 public constant PAUSER_ROLE      = keccak256("PAUSER_ROLE");        /// @notice Role that can pause transfers
    bytes32 public constant BLACKLISTER_ROLE = keccak256("BLACKLISTER_ROLE");   /// @notice Role than can blacklist addresses

    /**======================================

    MODIFIER FUNCTIONS

    =========================================**/

    modifier onlyPauser(address user){
        require(IAccessControl.hasRole(PAUSER_ROLE), "Not Pauser");
        _;
    }

    modifier onlyBlackLister(address user){
        require(IAccessControl.hasRole(BLACKLISTER_ROLE), "Not Blacklister");
        _;
    }

    modifier whenNotBlackListed(address user){
        require(IHestyAccessControl(ctrHestyControl).isUserBlackListed(user), "Blacklisted");
        _;
    }

    modifier whenKYCApproved(address user){
        require(IHestyAccessControl(ctrHestyControl).isUserKYCValid(user), "No KYC Made");
        _;
    }

    modifier whenNotAllPaused(address to){
        require(IHestyAccessControl(ctrHestyControl).isAllPaused(to), "All Hesty Paused");
        _;
    }

    /**
    * @dev Mints initialSupply_ * 1 ether of tokens and transfers them
           to Token Factory
    *
    * See {ERC20-constructor}.
    */
    constructor(
        address tokenManagerContract_,
        uint256 initialSupply_,
        string memory  name_,
        string memory symbol_,
        address rewardAsset_,
        address ctrHestyControl_
    ) ERC20(name_, symbol_) IAccessControl() IAccessControlDefaultAdminRules(
    3 days,
     msg.sender // Explicit initial `DEFAULT_ADMIN_ROLE` holder
    ){

        //Pre-Seed Share
        _mint(address(tokenManagerContract_), initialSupply_ * 1 ether);

        rewardAsset     = IERC20(rewardAsset_);
        ctrHestyControl = ctrHestyControl_;

    }

    /**======================================

    MUTABLE FUNCTIONS

    =========================================**/

    /**
    * @notice Claims users dividends
      @param amount Token Amount that users wants to buy
    */

    function distributionRewards(uint256 amount) external{

        require(amount > BASIS_POINTS, "Amount too low");

        (bool success) = rewardAsset.transferFrom(msg.sender, address(this), amount);

        require(success, "Failed Transfer");

        dividendPerToken += amount * MULTIPLIER / super.totalSupply();

    }

    /**
    * @notice Claims users dividends
      @param  user User Address that will receive dividends
    */
    function claimDividensExternal(address user) external{
        claimDividends(user);
    }

    /**
    * @notice Claims users dividends

      @dev Checks if there is any dividends to distribute
           and send them directly to the wallet

           The math logic is simple:

           - dividendPerToken keeps track of all time rewards
             per token distributed to holders
           - xDividendPerToken keeps track of users already
             claimed rewards
           - xDividendPerToken is updated before each transfer
             to be able to keep track of the math for each wallet
           - Multiplier is just an helper to keep math precision

      @note Using multiplier helper keeps it simple
            but is not 100% precsie, but what is lost
            is neglectable
    */
    function claimDividends(address account) private{

        uint256 amount             = ( (dividendPerToken - xDividendPerToken[account]) * balanceOf(account) / MULTIPLIER);
        xDividendPerToken[account] = dividendPerToken;

        if(amount > 0){
            (bool success) = rewardAsset.transfer(account, amount);
            require(success, "Failed Transfer");
        }

    }

    /**
  * @dev Transfers users tokens from address msg.sender
           to address "to" using openzepplin standard
           but implements two internal Hesty mechanism:

           - A KYC requirement
           - Claims dividends to both addresses involved in
             in the transfer before transfer is completed
             to avoid math overhead
    *
    * See {ERC20-constructor}.
    */
    function transfer(address to, uint256 amount) override
                        whenNotBlackListed(to) whenKYCApproved(to) whenNotAllPaused(to) public returns(bool){

        claimDividends(payable(msg.sender));
        claimDividends(payable(to));
        return super.transfer(to, amount);
    }

    /**
  * @dev Transfers users tokens from address "from"
           to address "to" using openzepplin standard
           but implements multiple internal Hesty mechanism:

           - A KYC requirement
           - A blacklist requirement
           - Claims dividends to both addresses involved in
             in the transfer before transfer is completed
             to avoid math overhead
     @note This function implements two types of pause
            an unique pause
    *
    * See {ERC20-constructor}.
    */
    function transferFrom(address from, address to, uint256 amount) override
                           whenNotBlackListed(to) whenKYCApproved(to) whenNotAllPaused(to) public returns(bool){

        claimDividends(payable(from));
        claimDividends(payable(to));
        return super.transfer(to, amount);
    }

    function pause() override external onlyPauser(msg.sender){
        super._pause();
    }

    function unpause() override external onlyPauser(msg.sender){
        super._unpause();
    }
}