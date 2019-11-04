pragma solidity ^0.5.0;

contract AssetTransfer {
    event ContractCreated(string applicationName, string workflowName, address originatingAddress);
    event ContractUpdated(string applicationName, string workflowName, string action, address originatingAddress);

    string internal ApplicationName;
    string internal WorkflowName;

    function LogContractCreated() private {
        emit ContractCreated(ApplicationName, WorkflowName, msg.sender);
    }

    function LogContractUpdated(string memory action) private {
        emit ContractUpdated(ApplicationName, WorkflowName, action, msg.sender);
    }

    enum StateType {
        Active,
        OfferPlaced,
        PendingInspection,
        Inspected,
        Appraised,
        NotionalAcceptance,
        BuyerAccepted,
        SellerAccepted,
        Accepted,
        Terminated
    }

    address public InstanceOwner;
    string public Description;
    uint public AskingPrice;
    StateType public State;

    address public InstanceBuyer;
    uint public OfferPrice;
    address public InstanceInspector;
    address public InstanceAppraiser;

    constructor (string memory description, uint256 price) public {
        ApplicationName = "AssetTransfer";
        WorkflowName = "AssetTransfer";
        InstanceOwner = msg.sender;
        AskingPrice = price;
        Description = description;
        State = StateType.Active;
        LogContractCreated();
    }

    function Terminate() public {
        if (InstanceOwner != msg.sender) {
            revert("The contract can only be terminated by the owner");
        }

        State = StateType.Terminated;
        LogContractUpdated('Terminate');
    }

    function Modify(string calldata description, uint256 price) external {
        if (State != StateType.Active) {
            revert("Modify function can only be called when in Active state");
        }

        if (InstanceOwner != msg.sender) {
            revert("Modify function can only be called by the owner");
        }

        Description = description;
        AskingPrice = price;
        LogContractUpdated('Modify');
    }

    function MakeOffer(address inspector, address appraiser, uint256 offerPrice) external {
        if (inspector == address(0x000) || appraiser == address(0x000) || offerPrice == 0) {
            revert("MakeOffer function need to have a valid inspector/appraiser address and an offerPrice > 0");
        }

        if (State != StateType.Active) {
            revert("MakeOffer function can only be called when in Active state");
        }

        if (InstanceOwner == msg.sender) {
            revert("MakeOffer function cannot be called by the owner");
        }

        InstanceBuyer = msg.sender;
        InstanceInspector = inspector;
        InstanceAppraiser = appraiser;
        OfferPrice = offerPrice;
        State = StateType.OfferPlaced;
        LogContractUpdated('MakeOffer');
    }

    function AcceptOffer() external {
        if (State != StateType.OfferPlaced) {
            revert("AcceptOffer function can only be called when an Offer has already been placed.");
        }

        if (InstanceOwner != msg.sender) {
            revert("AcceptOffer function can only be called by the owner");
        }

        State = StateType.PendingInspection;
        LogContractUpdated("AcceptOffer");
    }

    function Reject() external {
        if (State != StateType.OfferPlaced && State != StateType.PendingInspection &&
            State != StateType.Inspected && State != StateType.Appraised &&
            State != StateType.NotionalAcceptance && State != StateType.BuyerAccepted) {
            revert("Current state does not allow the Reject function to be called");
        }

        if (InstanceOwner != msg.sender) {
            revert("Reject function can only be called by the owner");
        }

        InstanceBuyer = address(0x000);
        State = StateType.Active;
        LogContractUpdated("Reject");
    }

    function Accept() external {
        if (msg.sender != InstanceBuyer && msg.sender != InstanceOwner) {
            revert("Accept function can only be called by the Buyer or the Owner");
        }

        if (msg.sender == InstanceOwner && State != StateType.NotionalAcceptance && State != StateType.BuyerAccepted) {
            revert("Accept function can only be called by the Owner and no acceptance");
        }

        if (msg.sender == InstanceBuyer && State != StateType.NotionalAcceptance && State != StateType.SellerAccepted) {
            revert("Accept function can only be called by Buyer and no acceptance");
        }

        if (msg.sender == InstanceBuyer) {
            if (State == StateType.NotionalAcceptance) {
                State = StateType.BuyerAccepted;
            }
            else if (State == StateType.SellerAccepted) {
                State = StateType.Accepted;
            }
        } else {
            if (State == StateType.NotionalAcceptance) {
                State = StateType.SellerAccepted;
            } else if (State == StateType.BuyerAccepted) {
                State = StateType.Accepted;
            }
        }

        LogContractUpdated("Accept");
    }

    function ModifyOffer(uint256 offerPrice) external {
        if (State != StateType.OfferPlaced) {
            revert("ModifyOffer function cannot be called if an offer has been placed.");
        }

        if (InstanceBuyer != msg.sender || offerPrice == 0) {
            revert("ModifyOffer can only be called by Buyer with an offerPrice > 0");
        }

        OfferPrice = offerPrice;
        LogContractUpdated("ModifyOffer");
    }

    function RescindOffer() external {
        if (State != StateType.OfferPlaced && State != StateType.PendingInspection &&
            State != StateType.Inspected && State != StateType.Appraised &&
            State != StateType.NotionalAcceptance && State != StateType.SellerAccepted) {
            revert("RescindOffer function criteria was not met");
        }

        if (InstanceBuyer != msg.sender) {
            revert("RescindOffer function can only be called by the Buyer");
        }

        InstanceBuyer = address(0x000);
        OfferPrice = 0;
        State = StateType.Active;
        LogContractUpdated("RescindOffer");
    }

    function MarkAppraised() external {
        if (InstanceAppraiser != msg.sender) {
            revert("MarkAppraised function can only be called by the Appraiser");
        }

        if (State == StateType.PendingInspection) {
            State = StateType.Appraised;
        } else if (State == StateType.Inspected) {
            State = StateType.NotionalAcceptance;
        } else {
            revert("MarkAppraised function was not PendingInspection or Inspection");
        }

        LogContractUpdated("MarkAppraised");
    }

    function MarkInspected() external {
        if (InstanceInspector != msg.sender) {
            revert("MarkInspected function cannot be called by the Inspector");
        }

        if (State == StateType.PendingInspection) {
            State = StateType.Inspected;
        } else if (State == StateType.Appraised) {
            State = StateType.NotionalAcceptance;
        } else {
            revert("MarkInspected function can only be called if PendingInspected or Appraised");
        }

        LogContractUpdated("MarkInspected");
    }
}