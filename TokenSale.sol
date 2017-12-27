pragma solidity ^0.4.16;

import "./Token.sol";

contract TokenSale is Ownable {
    using SafeMath for uint;

    // Constants
    // =========
    uint private constant millions = 1e6;

    uint private constant CAP = 15*millions;
    uint private constant SALE_CAP = 12*millions;

    uint public price = 0.002 ether;

    // Events
    // ======

    event AltBuy(address holder, uint tokens, string txHash);
    event Buy(address holder, uint tokens);
    event RunSale();
    event PauseSale();
    event FinishSale();
    event PriceSet(uint weiPerNYX);

    // State variables
    // ===============
    bool public presale;
    NYXToken public token;
    address authority; //An account to control the contract on behalf of the owner
    address robot; //An account to purchase tokens for altcoins
    bool public isOpen = false;

    // Constructor
    // ===========

    function TokenSale(address _token, address _multisig, address _authority, address _robot){
        token = NYXToken(_token);
        authority = _authority;
        robot = _robot;
        transferOwnership(_multisig);
    }

    // Public functions
    // ================
    function togglePresale(bool activate) onlyOwner {
        presale = activate;
    }


    function getCurrentPrice() constant returns(uint) {
        if(presale) {
            return price - (price*20/100);
        }
        return price;
    }
    /**
    * Computes number of tokens with bonus for the specified ether. Correctly
    * adds bonuses if the sum is large enough to belong to several bonus intervals
    */
    function getTokensAmount(uint etherVal) constant returns (uint) {
        uint tokens = 0;
        tokens += etherVal/getCurrentPrice();
        return tokens;
    }

    function buy(address to) onlyOpen payable{
        uint amount = msg.value;
        uint tokens = getTokensAmountUnderCap(amount);
        
        owner.transfer(amount);

		token.mint(to, tokens);

        Buy(to, tokens);
    }

    function () payable{
        buy(msg.sender);
    }

    // Modifiers
    // =================

    modifier onlyAuthority() {
        require(msg.sender == authority || msg.sender == owner);
        _;
    }

    modifier onlyRobot() {
        require(msg.sender == robot);
        _;
    }

    modifier onlyOpen() {
        require(isOpen);
        _;
    }

    // Priveleged functions
    // ====================

    /**
    * Used to buy tokens for altcoins.
    * Robot may call it before TokenSale officially starts to migrate early investors
    */
    function buyAlt(address to, uint etherAmount, string _txHash) onlyRobot {
        uint tokens = getTokensAmountUnderCap(etherAmount);
        token.mint(to, tokens);
        AltBuy(to, tokens, _txHash);
    }

    function setAuthority(address _authority) onlyOwner {
        authority = _authority;
    }

    function setRobot(address _robot) onlyAuthority {
        robot = _robot;
    }

    function setPrice(uint etherPerNYX) onlyAuthority {
        price = etherPerNYX;
        PriceSet(price);
    }

    // SALE state management: start / pause / finalize
    // --------------------------------------------
    function open(bool open) onlyAuthority {
        isOpen = open;
        open ? RunSale() : PauseSale();
    }

    function finalize() onlyAuthority {
        uint diff = CAP.sub(token.totalSupply());
        if(diff > 0) //The unsold capacity moves to team
            token.mint(owner, diff);
        selfdestruct(owner);
        FinishSale();
    }

    // Private functions
    // =========================

    /**
    * Gets tokens for specified ether provided that they are still under the cap
    */
    function getTokensAmountUnderCap(uint etherAmount) private constant returns (uint){
        uint tokens = getTokensAmount(etherAmount);
        require(tokens > 0);
        require(tokens.add(token.totalSupply()) <= SALE_CAP);
        return tokens;
    }

}