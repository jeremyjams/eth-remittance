pragma solidity >=0.4.21 <0.7.0;

import "./Pausable.sol";
import "./SafeMath.sol";
import "./GlobalHub.sol";
import "./LocalShop.sol";

contract GlobalHub is Pausable {

    using SafeMath for uint;
    // Equals to `bytes4(keccak256("grant(address,bytes32,uint256)"))`
    bytes4 private constant LOCAL_SHOP_GRANT_SELECTOR = 0xb392f84d;
    uint public constant MAX_CLAIMABLE_AFTER_N_HOURS = 24 hours;
    uint public defaultHubCut;

    // shopAddress -> ShopPolicy
    mapping(address => ShopPolicy) public shopPolicies;
    // shop address list for end customers
    address[] public shops;
    // address owner => uint income, where an owner can withdraw its income
    mapping(address => uint) public incomes;
    mapping(bytes32 => bool) public isChallengeUsedList;

    struct ShopPolicy {
        bool isDeployed;
        bool isApproved;
        uint hubCut;
    }

    event CreateShopEvent(address indexed shopOwner, address indexed shop, uint hubCut);
    event ApproveShopEvent(address indexed hubOwner, address indexed shop);
    event BannedShopEvent(address indexed hubOwner, address indexed shop);
    event HubCutUpdateShopEvent(address indexed hubOwner, address indexedshop, uint hubCut);
    event GlobalHubGrantEvent(address indexed sender, uint amount, address indexed shop, bytes32 indexed challenge, uint claimableDate);
    event NewIncomeEvent(address indexed sender, uint amount);
    event WithdrawIncomeEvent(address indexed sender, uint amount);

    constructor(bool _paused, uint hubCut) Pausable(_paused) public {
        setDefaultHubCut(hubCut);
    }

    function generateChallenge(address redeemer, bytes32 password) public view returns (bytes32 challenge) {
        require(redeemer != address(0), "Empty redeemer");
        require(password != 0, "Empty password");

        challenge = keccak256(abi.encodePacked(address(this), redeemer, password));
    }

    function setDefaultHubCut(uint _defaultHubCut) public whenNotPaused onlyOwner returns (bool) {
        defaultHubCut = _defaultHubCut;
        return true;
    }

    function createLocalShop(uint localCut) public payable whenNotPaused returns (bool) {
        // todo pay for creation
        LocalShop shop = (new LocalShop)(msg.sender, localCut, false);
        ShopPolicy storage shopPolicy = shopPolicies[address(shop)];
        shopPolicy.isDeployed = true;
        shopPolicy.hubCut = defaultHubCut;
        shops.push(address(shop));
        emit CreateShopEvent(msg.sender, address(shop), defaultHubCut);
        return true;
    }

    function approveLocalShop(address shop) public onlyOwner returns (bool) {
        ShopPolicy storage shopPolicy = shopPolicies[shop];
        require(shopPolicy.isDeployed, "Shop should be deployed");
        require(!shopPolicy.isApproved, "Shop is already approved");
        shopPolicy.isApproved = true;
        emit ApproveShopEvent(msg.sender, shop);
        return true;
    }

    function banLocalShop(address shop) public onlyOwner returns (bool) {
        ShopPolicy storage shopPolicy = shopPolicies[shop];
        require(shopPolicy.isDeployed, "Shop should be deployed");
        require(shopPolicy.isApproved, "Shop is already banned");
        shopPolicy.isApproved = false;
        emit BannedShopEvent(msg.sender, shop);
        return true;
    }

    function updateLocalShopHubCut(address shop, uint hubCut) public onlyOwner returns (bool) {
        ShopPolicy storage shopPolicy = shopPolicies[shop];
        require(shopPolicy.isDeployed, "Shop should be deployed");
        shopPolicy.hubCut = hubCut;
        emit HubCutUpdateShopEvent(msg.sender, shop, hubCut);
        return true;
    }


    /*
    * challenge is the ID of the grant
    */
    function grant(bytes32 challenge, uint claimableAfterNHours, address shop) public payable whenNotPaused returns (bool) {
        require(challenge != 0, "Empty challenge");
        require(claimableAfterNHours < MAX_CLAIMABLE_AFTER_N_HOURS, "Claim period should be less than 24 hours");
        require(isChallengeUsedList[challenge] == false, "Challenge already used by someone");
        ShopPolicy storage shopPolicy = shopPolicies[shop];
        require(shopPolicy.isApproved, "Shop should be approved");
        uint hubCut = shopPolicy.hubCut;
        require(msg.value > shopPolicy.hubCut, "Grant should be greater than hub cut");

        isChallengeUsedList[challenge] = true;

        uint amount;
        if(hubCut > 0){
            address owner = owner();
            incomes[owner] = incomes[owner].add(hubCut);
            emit NewIncomeEvent(owner, hubCut);
            amount = msg.value.sub(hubCut);
        } else {
            amount = msg.value;
        }
        uint claimableDate = now.add(claimableAfterNHours.mul(1 hours));

        (bool isSuccess, bytes memory returnedData) = shop
        .call(abi.encodeWithSelector(LOCAL_SHOP_GRANT_SELECTOR, msg.sender, challenge, claimableDate));
        require(isSuccess, "Internal call failed: shop.grant(granter, challenge, claimableDate)");
        require(abi.decode(returnedData, (bool)) == true, "Failed");

        emit GlobalHubGrantEvent(msg.sender, amount, shop, challenge, claimableDate);
        return true;
    }


    /*
     * Anyone with income can withdraw it
     */
    function withdrawIncome() public whenNotPaused returns (bool success) {
        uint income = incomes[msg.sender];
        require(income > 0, "Empty income");
        incomes[msg.sender] = 0;
        emit WithdrawIncomeEvent(msg.sender, income);
        (success,) = msg.sender.call.value(income)("");
        require(success, "WithdrawIncome transfer failed");
    }

}
