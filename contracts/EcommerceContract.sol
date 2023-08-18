// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

error UnauthorizedSeller();

error UnauthorizedOwner();

error InexistentProduct();

error DisputeError(string errorMessage);

error InsufficientPayment();

error ProductAlreadyExists();

contract DecentralizedEcommerce {
    using Counters for Counters.Counter;

    Counters.Counter private _productIds;

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

    // Event to log new product creation
    event ProductCreated(
        uint256 productId,
        address seller,
        string cid,
        uint256 price
    );

    // Event to log dispute resolution
    event DisputeResolved(uint256 productId, address resolver, address winner);

    // Mapping to track user points
    mapping(address => uint256) public userPoints;

    mapping(uint256 => bool) public productExists;

    modifier productIdExists(uint256 _productId) {
        if (!productExists[_productId]) {
            revert InexistentProduct();
        }
        _;
    }

    constructor() {
        _productIds.increment();
    }

    // Function to create a new product
    function createProduct(string memory cid, uint256 price) external {
        uint256 productId = _productIds.current();
        //require(!productsExists[productId], "Product already exists");

        //used reverts instead of require to save gas at deployment
        if (productExists[productId]) {
            revert ProductAlreadyExists();
        }

        productsIdToProducts[productId] = Product(
            productId,
            msg.sender,
            cid,
            price,
            false
        );
        productExists[productId] = true;
        products.push(productsIdToProducts[productId]);
        _productIds.increment();

        emit ProductCreated(productId, msg.sender, cid, price);
    }

    // Function to initiate a dispute
    function initiateDispute(
        uint256 _productId
    ) external productIdExists(_productId) {
        //require(products[productId].exists, "Product does not exist");

        //require(msg.sender != products[productId].seller, "Cannot dispute your own product");

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
        //require(products[productId].exists, "Product does not exist");

        //require(msg.value >= productsIdToProducts[productId].price, "Insufficient payment");

        //used reverts instead of require to save gas at deployment
        if (msg.value < productsIdToProducts[_productId].price) {
            revert InsufficientPayment();
        }

        // Calculate and reward points
        uint256 points = productsIdToProducts[_productId].price / 100; // 1% of the price
        userPoints[msg.sender] += points;

        // Transfer payment to the seller
        address payable seller = payable(
            productsIdToProducts[_productId].seller
        );
        seller.transfer(msg.value);

        // Remove the product after successful purchase
        delete productsIdToProducts[_productId];
        delete products[_productId];
    }
}
