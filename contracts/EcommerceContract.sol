// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

error UnauthorizedSeller();

error UnauthorizedCaller();

error InexistentProduct();

error DisputeError(string errorMessage);

error InsufficientPayment();

error ProductAlreadyExists();

error ProductAlreadyRemoved();

error ProductAlreadySold();

error UnauthorizedClaim();

error InSufficientPoints();

error BelowMinimumPrice();

contract DecentralizedEcommerce is Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _productIds;
    Counters.Counter private _indexCounter;

    //uint256 private feeRatio;

    uint256 private minimumListingFee = 0.5 ether;

    uint256 private pointsThreshold = 500;

    uint256 private pointsThresholdAllocation = 0.001 ether;

    //address private reserveContract;

    // Structure to store product details
    struct Product {
        uint256 id;
        address seller;
        string cid; // Content Identifier
        uint256 price;
        bool sold;
    }

    Product[] public products;

    // Mapping to store products by their unique identifiers
    mapping(uint256 => Product) public productsIdToProducts;

    mapping(uint256 => uint256) public productsIdToIndex;

    mapping(address => Product[]) internal ownerToProducts;

    mapping(uint256 => address) public productIdToOwner;

    mapping(uint256 => bool) public hasBeenRemoved;

    // Event to log new product creation
    event ProductCreated(
        uint256 productId,
        address seller,
        string cid,
        uint256 price
    );

    // Event to log dispute resolution
    event DisputeResolved(
        uint256 productId,
        address indexed resolver,
        address indexed winner
    );

    event PurchaseSuccessful(uint256 productId, address indexed buyer);

    // Mapping to track user points
    mapping(address => uint256) public userPoints;

    mapping(uint256 => bool) public productExists;

    modifier productIdExists(uint256 _productId) {
        if (!productExists[_productId]) {
            revert InexistentProduct();
        }
        _;
    }

    constructor() /*uint256 _feePercentage , address _reserveContract*/ {
        _productIds.increment();
        //reserveContract = _reserveContract;
        // uint256 _feePercentageBigN = _feePercentage * 10 ** 18;
        // feeRatio = _feePercentageBigN / 100;
    }

    // Function to create a new product
    function createProduct(string memory cid, uint256 price) external {
        uint256 productId = _productIds.current();
        uint256 index = _indexCounter.current();

        // //used reverts instead of require to save gas at deployment
        // if (productExists[productId]) {
        //     revert ProductAlreadyExists();
        // }

        if (price < minimumListingFee) {
            revert BelowMinimumPrice();
        }

        productsIdToProducts[productId] = Product(
            productId,
            msg.sender,
            cid,
            price,
            false
        );
        productsIdToIndex[productId] = index;
        productExists[productId] = true;
        ownerToProducts[msg.sender].push(productsIdToProducts[productId]);
        productIdToOwner[productId] = msg.sender;
        products.push(productsIdToProducts[productId]);
        _productIds.increment();

        emit ProductCreated(productId, msg.sender, cid, price);
    }

    // Function to initiate a dispute
    function initiateDispute(
        uint256 _productId
    ) external productIdExists(_productId) {
        //used reverts instead of require to save gas at deployment
        if (msg.sender == productsIdToProducts[_productId].seller) {
            revert DisputeError("You cannot dispute your own product");
        }

        // Implement dispute logic here
        // You might involve a DAO or a voting mechanism to resolve disputes

        // For this example, we'll emit the event
        emit DisputeResolved(
            _productId,
            msg.sender,
            productsIdToProducts[_productId].seller
        );
    }

    // Function to reward user points when buying a product
    function buyProduct(
        uint256 _productId
    ) external payable productIdExists(_productId) {
        //used reverts instead of require to save gas at deployment
        Product memory product = productsIdToProducts[_productId];
        address payable initialSeller = payable(product.seller);

        if (msg.value < product.price) {
            revert InsufficientPayment();
        }

        if (product.sold) {
            revert ProductAlreadySold();
        }

        // Calculate and reward points
        uint256 points = product.price / 10 ** 17; // 1% of the price
        //uint256 points = priceInPoints / 100;
        userPoints[msg.sender] += points;
        product.sold = true;
        product.seller = msg.sender;

        //delete previous owner of product
        _deleteFromOwnerArray(_productId);
        productIdToOwner[_productId] = msg.sender;
        ownerToProducts[msg.sender].push(product);

        productsIdToProducts[_productId] = product;

        //uint256 fee = product.price * feeRatio;
        uint256 fee = product.price / 50;
        uint256 sellerEarnings = product.price - fee;
        payable(address(this)).transfer(fee);
        initialSeller.transfer(sellerEarnings);

        emit PurchaseSuccessful(_productId, msg.sender);
    }

    function _deleteFromOwnerArray(uint256 _productId) internal {
        address productOwner = productIdToOwner[_productId];
        Product[] storage ownerProducts = ownerToProducts[productOwner];
        Product storage _product = productsIdToProducts[_productId];
        //uint256 productIndex = _getProductIdIndex(_productId);

        for (uint256 i = 0; i < ownerProducts.length; i++) {
            if (ownerProducts[i].id == _product.id) {
                // Replace the element at index i with the last element
                ownerProducts[i] = ownerProducts[ownerProducts.length - 1];
                // Remove the last element (pop)
                ownerProducts.pop();
                break; // Exit the loop after the first occurrence is removed
            }
        }
        ownerToProducts[productOwner] = ownerProducts;
    }

    function _getProductIdIndex(
        uint256 _productId
    ) internal view productIdExists(_productId) returns (uint256 _index) {
        _index = productsIdToIndex[_productId];
    }

    function getAllProducts()
        public
        view
        returns (Product[] memory allProducts)
    {
        allProducts = products;
    }

    function getProductsByOwnerAddress(
        address _owner
    ) public view returns (Product[] memory _products) {
        _products = ownerToProducts[_owner];
    }

    function removeProduct(
        uint256 _productId
    ) external productIdExists(_productId) {
        address seller = productsIdToProducts[_productId].seller;
        if (msg.sender != seller) {
            revert UnauthorizedSeller();
        }

        if (hasBeenRemoved[_productId]) {
            revert ProductAlreadyRemoved();
        }

        uint256 productIndex = _getProductIdIndex(_productId);
        _deleteFromOwnerArray(_productId);
        delete products[productIndex];
        delete productsIdToProducts[_productId];
        delete productIdToOwner[_productId];
        hasBeenRemoved[_productId] = true;
    }

    function getProductsById(
        uint256 _productId
    ) public view returns (Product memory _product) {
        _product = productsIdToProducts[_productId];
    }

    function getUserPoints(
        address _user
    ) public view returns (uint256 _userPoints) {
        _userPoints = userPoints[_user];
    }

    function redeemUserPoints(address payable user) public {
        uint256 points = userPoints[user];

        if (msg.sender != user) {
            revert UnauthorizedCaller();
        }

        if (points < pointsThreshold) {
            revert InSufficientPoints();
        }

        uint256 amount = points * pointsThresholdAllocation;

        //payable(user).transfer(amount);

        if (address(this).balance < amount) {
            revert("Insufficient contract balance");
        }

        userPoints[msg.sender] = 0; // Reset user's points

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    function resolveDispute() public {}

    //     function _deleteFromArray(address key, Product value, Product[] memory _dataArray) internal returns (Product[] memory newDataArr) {
    //     // Create a new array to hold the modified data
    //     Product[] memory updatedDataArray = new Product[](_dataArray.length - 1);
    //     uint256 currentIndex = 0;

    //     for (uint256 i = 0; i < _dataArray.length; i++) {
    //         if (_dataArray[i].id != value.id) {
    //             // Only copy non-matching elements to the updated array
    //             updatedDataArray[currentIndex] = _dataArray[i];
    //             currentIndex++;
    //         }
    //     }

    //     // Set the newDataArr variable to the updated array
    //     newDataArr = updatedDataArray;
    // }

    receive() external payable {
        // Handle the received Ether here
    }
}
