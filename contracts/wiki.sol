// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

 import "@openzeppelin/contracts/token/ERC721/ERC721.sol"; 
import "./ReputationToken.sol";

contract WikipediaApp is ERC721 {

    address payable owner;
    ReputationToken public reputationToken;

    struct User {
        address wallet;
        ReputationToken reputationToken; 
    }


    struct Article {
        string title;
        string content;
        uint256 upvotes;
        uint256 downvotes;
        bool posted;
        uint256 createdAt;
        uint256[] updateIds;
        address creator;
    }

    struct Update {
        string newContent;
        uint256 upvotes;
        uint256 downvotes;
        bool applied;
        uint256 createdAt;
        uint256 articleId;
    }

    mapping(uint256 => Article) public articles;
    mapping(address => User) public users;
    mapping(uint256 => Update) public updates;
    uint256 public articleCount = 0;
    uint256 public updateCount = 0;

    event ArticleCreated(uint256 indexed articleId, string title, address creator);
    event ArticlePosted(uint256 indexed articleId);
    event UpdateSubmitted(uint256 indexed articleId, uint256 indexed updateId);
    event UpdateApplied(uint256 indexed articleId, uint256 indexed updateId);
    event ArticleDeleted(uint256 indexed articleId);
    event ArticleUpvoted(uint256 indexed articleId);
    event ArticleDownvoted(uint256 indexed articleId);
    event ArticleUpvotedBeforePosting(uint256 indexed articleId);
    event ArticleDownvotedBeforePosting(uint256 indexed articleId);

    modifier onlyOwner {
        require(msg.sender == owner, "Only owner of the contract can perform this action");
        _;
    }

    modifier articleExists(uint256 _articleId) {
        require(_articleId < articleCount, "Invalid article ID");
        _;
    }

    modifier updateExists(uint256 _updateId) {
        require(_updateId < updateCount, "Invalid update ID");
        _;
    }

    constructor(address _reputationToken) ERC721("Article Owner", "MyArticle") {
        owner = payable(msg.sender);
        reputationToken = ReputationToken(_reputationToken);
    }

    function registerUser(address _wallet, address _reputationToken) public {
        require(_wallet != address(0), "Invalid wallet address");
        require(users[_wallet].wallet == address(0), "User already registered");
        users[_wallet] = User(_wallet, ReputationToken(_reputationToken));
        // Set initial reputation to 0
        users[_wallet].reputationToken.mint(_wallet, 0);
    }

    function getUserDetails(address _user) public view returns(address, ReputationToken){
        return (users[_user].wallet, users[_user].reputationToken);
    }

    function createArticle(string memory _title, string memory _content) private {
        articles[articleCount] = Article({
            title: _title,
            content: _content,
            upvotes: 0,
            downvotes: 0,
            posted: false,
            createdAt: block.timestamp,
            updateIds: new uint256[](0) ,
            creator: msg.sender
        });
        emit ArticleCreated(articleCount, _title, msg.sender);
         // Mint 10 RPT tokens to the article creator
        articleCount++;
    }

    function submitUpdate(uint256 _articleId, string memory _newContent) public articleExists(_articleId) {
        uint256 updateId = updateCount++;
        updates[updateId] = Update({
            newContent: _newContent,
            upvotes: 0,
            downvotes: 0,
            applied: false,
            createdAt: block.timestamp,
            articleId: _articleId
        });
        articles[_articleId].updateIds.push(updateId);
        emit UpdateSubmitted(_articleId, updateId);
         // Mint 5 RPT tokens to the update creator
    }

    function upvoteArticle(uint256 _articleId) public articleExists(_articleId) {
        Article storage article = articles[_articleId];
        article.upvotes++;
        emit ArticleUpvoted(_articleId);
        checkArticleForPosting(_articleId);
    }

    function downvoteArticle(uint256 _articleId) public articleExists(_articleId) {
        Article storage article = articles[_articleId];
        article.downvotes++;
        emit ArticleDownvoted(_articleId);
        checkArticleForPosting(_articleId);
    }

    function checkArticleForPosting(uint256 _articleId) internal {
        Article storage article = articles[_articleId];
        if (!article.posted && block.timestamp >= article.createdAt + 5 minutes) {
            if (article.upvotes > article.downvotes) {
                article.posted = true;
                article.downvotes = 0;
                article.upvotes = 0;
                emit ArticlePosted(_articleId);
                reputationToken.mint(msg.sender, 10 * 10 ** 18);
            }
        }
    }

    function upvoteUpdate(uint256 _updateId) public updateExists(_updateId) {
        updates[_updateId].upvotes++;
        checkUpdateForApplying(_updateId);
    }

    function downvoteUpdate(uint256 _updateId) public updateExists(_updateId) {
        updates[_updateId].downvotes++;
        checkUpdateForApplying(_updateId);
    }

    function checkUpdateForApplying(uint256 _updateId) internal {
        Update storage update = updates[_updateId];
        if (!update.applied && block.timestamp >= update.createdAt + 5 minutes) {
            if (update.upvotes > update.downvotes) {
                update.applied = true;
                emit UpdateApplied(update.articleId, _updateId);
                reputationToken.mint(msg.sender, 5 * 10 ** 18);

                // Append the content of the update to the article
                Article storage article = articles[update.articleId];
                article.content = string(abi.encodePacked(article.content, "\n", update.newContent));

                // Delete the update
                delete updates[_updateId];
            }
        }
    }

    function deleteArticle(uint256 _articleId) public articleExists(_articleId) {
        Article storage article = articles[_articleId];
        require(!article.posted, "Article already posted");
        require(block.timestamp >= article.createdAt + 5 minutes, "Article needs to wait for 5 minutes");
        require(article.downvotes > article.upvotes, "Downvotes must be greater than upvotes");
        delete articles[_articleId];
        emit ArticleDeleted(_articleId);
    }

    function getArticle(uint256 _articleId) public view returns (string memory, string memory, uint256, uint256, bool, uint256, address) {
        require(_articleId < articleCount, "Invalid article ID");
        Article memory article = articles[_articleId];
        return (
            article.title,
            article.content,
            article.upvotes,
            article.downvotes,
            article.posted,
            article.createdAt,
            article.creator
        );
    }

    function getAtricleByTitle(string memory _title) public view returns(string memory, string memory, uint256, uint256, bool, uint256, address){
        for(uint256 i = 0; i < articleCount; i++){
            if(keccak256(abi.encodePacked(articles[i].title)) == keccak256(abi.encodePacked(_title))){
                return getArticle(i);
            }
        }
    }

    function getUpdate(uint256 _updateId) public view returns (string memory, uint256, uint256, bool, uint256, uint256) {
        require(_updateId < updateCount, "Invalid update ID");
        Update memory update = updates[_updateId];
        return (
            update.newContent,
            update.upvotes,
            update.downvotes,
            update.applied,
            update.createdAt,
            update.articleId
        );
    }

    function viewPendingArticles() public view returns (Article[] memory) {
        uint256 pendingArticleCount = 0;
        for (uint256 i = 0; i < articleCount; i++) {
            Article memory article = articles[i];
            if ((!article.posted && (block.timestamp >= article.createdAt + 5 minutes && article.upvotes > article.downvotes)) || block.timestamp < article.createdAt + 5 minutes) {
                pendingArticleCount++;
            }
        }

        Article[] memory pendingArticles = new Article[](pendingArticleCount);
        uint256 index = 0;

        for (uint256 i = 0; i < articleCount; i++) {
            Article memory article = articles[i];
            if ((!article.posted && (block.timestamp >= article.createdAt + 5 minutes && article.upvotes > article.downvotes)) || block.timestamp < article.createdAt + 5 minutes) {
                pendingArticles[index] = article;
                index++;
            }
        }

        return pendingArticles;
    }

    function viewPendingUpdates() public view returns (Update[] memory) {
        uint256 pendingUpdateCount = 0;
        // Count the number of pending updates
        for (uint256 i = 0; i < updateCount; i++) {
            if (!updates[i].applied) {
                pendingUpdateCount++;
            }
        }
        // Initialize array to store pending updates
        Update[] memory pendingUpdates = new Update[](pendingUpdateCount);
        uint256 index = 0;
        // Populate the array with pending updates
        for (uint256 i = 0; i < updateCount; i++) {
            if (!updates[i].applied) {
                pendingUpdates[index] = updates[i];
                index++;
            }
        }
        return pendingUpdates;
    }
}
