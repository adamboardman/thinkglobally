module Tests exposing (decodeApiAction, decodeConcept, decodeLogin, decodeRegister, decodeUser, failsWithMissingJson, pendingTransactionSummaryOfferIn, pendingTransactionSummaryOfferOut, pendingTransactionSummaryRequestIn, pendingTransactionSummaryRequestOut, success, testUser1, testUser2, transactionSummaryOfferApprovedIn, transactionSummaryOfferApprovedOut, transactionSummaryRequestApprovedIn, transactionSummaryRequestApprovedOut)

import Bootstrap.Button as Button
import Bootstrap.Modal as Modal
import Bootstrap.Table as Table exposing (rowAttr)
import Dict
import Expect exposing (Expectation)
import Html exposing (text)
import Html.Attributes exposing (style)
import Json.Decode
import Loading
import Login exposing (loginDecoder)
import Test exposing (..)
import Time
import Transaction exposing (pendingTransactionSummary, transactionSummary)
import Types exposing (Msg(..), Page(..), TransactionType(..), User, apiActionDecoder, conceptDecoder, emptyConcept, emptyConceptForm, emptyProfileForm, emptyTransactionForm, emptyUser, formatBalance, formatBalancePlusFee, formatBalanceWithMultiplier, formatDate, userDecoder)


decodeLogin : Test
decodeLogin =
    test "decode login response json" <|
        \() ->
            let
                input =
                    """
                    {"status":200,"expire":"2019-07-24T15:21:44+01:00","token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJjb25maXJtZWQiOnRydWUsImVtYWlsIjoidGVzdDlAZXhhbXBsZS5jb20iLCJleHAiOjE1NjM5NzgxMDQsImlkIjoyNzgsIm9yaWdfaWF0IjoxNTYzMzczMzA0fQ.9U1L7SKH4ISwwNGwQ9giNCC2q5UMXT0Tw2WQ5f4itVU"}
                    """

                decodedOutput =
                    Json.Decode.decodeString
                        loginDecoder
                        input
            in
            Expect.equal decodedOutput
                (Ok
                    { loginExpire = "2019-07-24T15:21:44+01:00"
                    , loginToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJjb25maXJtZWQiOnRydWUsImVtYWlsIjoidGVzdDlAZXhhbXBsZS5jb20iLCJleHAiOjE1NjM5NzgxMDQsImlkIjoyNzgsIm9yaWdfaWF0IjoxNTYzMzczMzA0fQ.9U1L7SKH4ISwwNGwQ9giNCC2q5UMXT0Tw2WQ5f4itVU"
                    }
                )


success : Result a b -> Bool
success result =
    case result of
        Ok _ ->
            True

        Err _ ->
            False


failsWithMissingJson : Test
failsWithMissingJson =
    test "fail on wrong login json response" <|
        \() ->
            let
                input =
                    """
                        {"expire":1,"token":2}
                        """

                decodedOutput =
                    Json.Decode.decodeString
                        loginDecoder
                        input
            in
            Expect.equal (success decodedOutput) False


decodeRegister : Test
decodeRegister =
    test "decode register response json" <|
        \() ->
            let
                input =
                    """
                    {"message":"User registered successfully","resourceId":315,"status":200}
                    """

                decodedOutput =
                    Json.Decode.decodeString
                        apiActionDecoder
                        input
            in
            Expect.equal decodedOutput
                (Ok
                    { status = 200
                    , resourceId = 315
                    , resourceIds = []
                    }
                )


decodeUser : Test
decodeUser =
    test "decode user response json" <|
        \() ->
            let
                input =
                    """
                    {"ID":9,"CreatedAt":"2019-07-11T14:50:37.443151+01:00","UpdatedAt":"2019-07-13T21:02:21.214296+01:00","DeletedAt":null,"FirstName":"FNS","MidNames":"MN","LastName":"LN","Location":"LOC","PhotoID":0,"Email":"EAD","Mobile":"MOB","Confirmed":true,"Permissions":1}
                    """

                decodedOutput =
                    Json.Decode.decodeString
                        userDecoder
                        input
            in
            Expect.equal decodedOutput
                (Ok
                    { id = 9
                    , firstName = "FNS"
                    , midNames = "MN"
                    , lastName = "LN"
                    , location = "LOC"
                    , email = "EAD"
                    , mobile = "MOB"
                    , permissions = 1
                    , balance = 0
                    }
                )


decodeConcept : Test
decodeConcept =
    test "decode concept response json" <|
        \() ->
            let
                input =
                    """
                   {"ID":21,"CreatedAt":"2019-07-12T11:27:37.338297+01:00","UpdatedAt":"2019-07-12T12:23:50.763285+01:00","DeletedAt":null,"Name":"Account Recovery","Summary":"lost secret keys","Full":"With TG's"}
                    """

                decodedOutput =
                    Json.Decode.decodeString
                        conceptDecoder
                        input
            in
            Expect.equal decodedOutput
                (Ok
                    { id = 21
                    , name = "Account Recovery"
                    , summary = "lost secret keys"
                    , full = "With TG's"
                    , tags = []
                    }
                )


decodeApiAction : Test
decodeApiAction =
    test "decode api action response json" <|
        \() ->
            let
                input =
                    """
                   {"message":"ConceptTag deleted","resourceIds":[437,34],"status":200}
                    """

                decodedOutput =
                    Json.Decode.decodeString
                        apiActionDecoder
                        input
            in
            Expect.equal decodedOutput
                (Ok
                    { resourceId = 0
                    , resourceIds = [ 437, 34 ]
                    , status = 200
                    }
                )


testUser1 : User
testUser1 =
    { id = 1
    , firstName = "FN1"
    , midNames = ""
    , lastName = "LN1"
    , location = ""
    , email = ""
    , mobile = ""
    , permissions = 0
    , balance = 0
    }


testUser2 : User
testUser2 =
    { id = 2
    , firstName = "FN2"
    , midNames = ""
    , lastName = "LN2"
    , location = ""
    , email = ""
    , mobile = ""
    , permissions = 0
    , balance = 0
    }


pendingTransactionSummaryOfferOut : Test
pendingTransactionSummaryOfferOut =
    test "pending transaction summary offer out" <|
        \() ->
            let
                model =
                    { navKey = Nothing
                    , navState = Nothing
                    , page = Home
                    , loading = Loading.Off
                    , problems = []
                    , loginForm = { email = "", password = "" }
                    , registerForm = { email = "", password = "", password_confirm = "" }
                    , session = { loginExpire = "", loginToken = "" }
                    , apiActionResponse = { status = 0, resourceId = 0, resourceIds = [] }
                    , loggedInUser = testUser1
                    , profileForm = emptyProfileForm
                    , transactionForm = emptyTransactionForm
                    , conceptForm = emptyConceptForm
                    , conceptTagForm = { tag = "" }
                    , concept = emptyConcept
                    , creatingTransaction = TxNone
                    , transactions = []
                    , pendingTransactions = []
                    , txUsers = Dict.fromList [ ( "1", testUser1 ), ( "2", testUser2 ) ]
                    , creatingTransactionWithUser = emptyUser
                    , timeZone = Time.utc
                    , time = Time.millisToPosix 0
                    , conceptsList = []
                    , conceptTagsList = []
                    , displayableTagsList = []
                    , conceptShowTagModel = Modal.hidden
                    }

                tx =
                    { id = 1
                    , initiatedDate = Time.millisToPosix 123
                    , confirmedDate = Time.millisToPosix 456
                    , fromUserId = 1
                    , toUserId = 2
                    , seconds = 3600
                    , multiplier = 1
                    , txFee = 1
                    , status = 1
                    , description = ""
                    , fromUserBalance = 0
                    , toUserBalance = 0
                    }
            in
            Expect.equal
                (pendingTransactionSummary model tx)
                (Table.tr
                    []
                    [ Table.td [] [ text (formatDate model tx.initiatedDate) ]
                    , Table.td [] [ text "F: ", text "Yourself", Html.br [] [], text "T: ", text "FN2 LN2 (2)" ]
                    , Table.td [] [ text (formatBalance -3601) ]
                    , Table.td [] [ text "F: ", text (formatBalance -3601), Html.br [] [], text "T: ", text (formatBalance 3600) ]
                    , Table.td [] [ text "Offer pending" ]
                    , Table.td [] [ text "" ]
                    , Table.td [] [ text "" ]
                    ]
                )


pendingTransactionSummaryOfferIn : Test
pendingTransactionSummaryOfferIn =
    test "pending transaction summary offer in" <|
        \() ->
            let
                model =
                    { navKey = Nothing
                    , navState = Nothing
                    , page = Home
                    , loading = Loading.Off
                    , problems = []
                    , loginForm = { email = "", password = "" }
                    , registerForm = { email = "", password = "", password_confirm = "" }
                    , session = { loginExpire = "", loginToken = "" }
                    , apiActionResponse = { status = 0, resourceId = 0, resourceIds = [] }
                    , loggedInUser = testUser2
                    , profileForm = emptyProfileForm
                    , transactionForm = emptyTransactionForm
                    , conceptForm = emptyConceptForm
                    , conceptTagForm = { tag = "" }
                    , concept = emptyConcept
                    , creatingTransaction = TxNone
                    , transactions = []
                    , pendingTransactions = []
                    , txUsers = Dict.fromList [ ( "1", testUser1 ), ( "2", testUser2 ) ]
                    , creatingTransactionWithUser = emptyUser
                    , timeZone = Time.utc
                    , time = Time.millisToPosix 0
                    , conceptsList = []
                    , conceptTagsList = []
                    , displayableTagsList = []
                    , conceptShowTagModel = Modal.hidden
                    }

                tx =
                    { id = 1
                    , initiatedDate = Time.millisToPosix 123
                    , confirmedDate = Time.millisToPosix 456
                    , fromUserId = 1
                    , toUserId = 2
                    , seconds = 3600
                    , multiplier = 1
                    , txFee = 1
                    , status = 1
                    , description = ""
                    , fromUserBalance = 0
                    , toUserBalance = 0
                    }
            in
            Expect.equal
                (pendingTransactionSummary model tx)
                (Table.tr
                    []
                    [ Table.td [] [ text (formatDate model tx.initiatedDate) ]
                    , Table.td [] [ text "F: ", text "FN1 LN1 (1)", Html.br [] [], text "T: ", text "Yourself" ]
                    , Table.td [] [ text (formatBalance 3600) ]
                    , Table.td [] [ text "F: ", text (formatBalance -3601), Html.br [] [], text "T: ", text (formatBalance 3600) ]
                    , Table.td [] [ text "Accept or Reject Offer" ]
                    , Table.td [] [ Button.button [ Button.primary, Button.onClick <| AcceptTransaction tx.id ] [ text "Accept" ] ]
                    , Table.td [] [ Button.button [ Button.primary, Button.onClick <| RejectTransaction tx.id ] [ text "Reject" ] ]
                    ]
                )


pendingTransactionSummaryRequestIn : Test
pendingTransactionSummaryRequestIn =
    test "pending transaction summary request in" <|
        \() ->
            let
                model =
                    { navKey = Nothing
                    , navState = Nothing
                    , page = Home
                    , loading = Loading.Off
                    , problems = []
                    , loginForm = { email = "", password = "" }
                    , registerForm = { email = "", password = "", password_confirm = "" }
                    , session = { loginExpire = "", loginToken = "" }
                    , apiActionResponse = { status = 0, resourceId = 0, resourceIds = [] }
                    , loggedInUser = testUser1
                    , profileForm = emptyProfileForm
                    , transactionForm = emptyTransactionForm
                    , conceptForm = emptyConceptForm
                    , conceptTagForm = { tag = "" }
                    , concept = emptyConcept
                    , creatingTransaction = TxNone
                    , transactions = []
                    , pendingTransactions = []
                    , txUsers = Dict.fromList [ ( "1", testUser1 ), ( "2", testUser2 ) ]
                    , creatingTransactionWithUser = emptyUser
                    , timeZone = Time.utc
                    , time = Time.millisToPosix 0
                    , conceptsList = []
                    , conceptTagsList = []
                    , displayableTagsList = []
                    , conceptShowTagModel = Modal.hidden
                    }

                tx =
                    { id = 1
                    , initiatedDate = Time.millisToPosix 123
                    , confirmedDate = Time.millisToPosix 456
                    , fromUserId = 2
                    , toUserId = 1
                    , seconds = 3600
                    , multiplier = 1
                    , txFee = 1
                    , status = 2
                    , description = ""
                    , fromUserBalance = 0
                    , toUserBalance = 0
                    }
            in
            Expect.equal
                (pendingTransactionSummary model tx)
                (Table.tr
                    []
                    [ Table.td [] [ text (formatDate model tx.initiatedDate) ]
                    , Table.td [] [ text "F: ", text "FN2 LN2 (2)", Html.br [] [], text "T: ", text "Yourself" ]
                    , Table.td [] [ text (formatBalance 3599) ]
                    , Table.td [] [ text "F: ", text (formatBalance -3600), Html.br [] [], text "T: ", text (formatBalance 3599) ]
                    , Table.td [] [ text "Request pending" ]
                    , Table.td [] [ text "" ]
                    , Table.td [] [ text "" ]
                    ]
                )


pendingTransactionSummaryRequestOut : Test
pendingTransactionSummaryRequestOut =
    test "pending transaction summary request out" <|
        \() ->
            let
                model =
                    { navKey = Nothing
                    , navState = Nothing
                    , page = Home
                    , loading = Loading.Off
                    , problems = []
                    , loginForm = { email = "", password = "" }
                    , registerForm = { email = "", password = "", password_confirm = "" }
                    , session = { loginExpire = "", loginToken = "" }
                    , apiActionResponse = { status = 0, resourceId = 0, resourceIds = [] }
                    , loggedInUser = testUser2
                    , profileForm = emptyProfileForm
                    , transactionForm = emptyTransactionForm
                    , conceptForm = emptyConceptForm
                    , conceptTagForm = { tag = "" }
                    , concept = emptyConcept
                    , creatingTransaction = TxNone
                    , transactions = []
                    , pendingTransactions = []
                    , txUsers = Dict.fromList [ ( "1", testUser1 ), ( "2", testUser2 ) ]
                    , creatingTransactionWithUser = emptyUser
                    , timeZone = Time.utc
                    , time = Time.millisToPosix 0
                    , conceptsList = []
                    , conceptTagsList = []
                    , displayableTagsList = []
                    , conceptShowTagModel = Modal.hidden
                    }

                tx =
                    { id = 1
                    , initiatedDate = Time.millisToPosix 123
                    , confirmedDate = Time.millisToPosix 478988656
                    , fromUserId = 2
                    , toUserId = 1
                    , seconds = 3600
                    , multiplier = 1
                    , txFee = 1
                    , status = 2
                    , description = ""
                    , fromUserBalance = 0
                    , toUserBalance = 0
                    }
            in
            Expect.equal
                (pendingTransactionSummary model tx)
                (Table.tr
                    []
                    [ Table.td [] [ text (formatDate model tx.initiatedDate) ]
                    , Table.td [] [ text "F: ", text "Yourself", Html.br [] [], text "T: ", text "FN1 LN1 (1)" ]
                    , Table.td [] [ text (formatBalance -3600) ]
                    , Table.td [] [ text "F: ", text (formatBalance -3600), Html.br [] [], text "T: ", text (formatBalance 3599) ]
                    , Table.td [] [ text "Accept or Reject Request" ]
                    , Table.td [] [ Button.button [ Button.primary, Button.onClick <| AcceptTransaction tx.id ] [ text "Accept" ] ]
                    , Table.td [] [ Button.button [ Button.primary, Button.onClick <| RejectTransaction tx.id ] [ text "Reject" ] ]
                    ]
                )



-- Tests for transaction summary


transactionSummaryOfferApprovedOut : Test
transactionSummaryOfferApprovedOut =
    test "transaction summary offer approved out" <|
        \() ->
            let
                model =
                    { navKey = Nothing
                    , navState = Nothing
                    , page = Home
                    , loading = Loading.Off
                    , problems = []
                    , loginForm = { email = "", password = "" }
                    , registerForm = { email = "", password = "", password_confirm = "" }
                    , session = { loginExpire = "", loginToken = "" }
                    , apiActionResponse = { status = 0, resourceId = 0, resourceIds = [] }
                    , loggedInUser = testUser1
                    , profileForm = emptyProfileForm
                    , transactionForm = emptyTransactionForm
                    , conceptForm = emptyConceptForm
                    , conceptTagForm = { tag = "" }
                    , concept = emptyConcept
                    , creatingTransaction = TxNone
                    , transactions = []
                    , pendingTransactions = []
                    , txUsers = Dict.fromList [ ( "1", testUser1 ), ( "2", testUser2 ) ]
                    , creatingTransactionWithUser = emptyUser
                    , timeZone = Time.utc
                    , time = Time.millisToPosix 0
                    , conceptsList = []
                    , conceptTagsList = []
                    , displayableTagsList = []
                    , conceptShowTagModel = Modal.hidden
                    }

                tx =
                    { id = 1
                    , initiatedDate = Time.millisToPosix 123
                    , confirmedDate = Time.millisToPosix 456
                    , fromUserId = 1
                    , toUserId = 2
                    , seconds = 3600
                    , multiplier = 1
                    , txFee = 1
                    , status = 3 --Offer Approved
                    , description = ""
                    , fromUserBalance = 3601
                    , toUserBalance = 3600
                    }
            in
            Expect.equal
                (transactionSummary model tx)
                (Table.tr
                    [ if tx.status > 4 then
                        rowAttr (style "color" "grey")

                      else
                        rowAttr (style "" "")
                    ]
                    [ Table.td [] [ text (formatDate model tx.initiatedDate) ]
                    , Table.td [] [ text "Yourself" ]
                    , Table.td [] [ text "FN2 LN2 (2)" ]
                    , Table.td [] [ text "Offer Approved" ]
                    , Table.td [] [ text "" ]
                    , Table.td [] [ text (formatBalancePlusFee tx.seconds tx.multiplier tx.txFee) ]
                    , Table.td [] [ text (formatBalance tx.fromUserBalance) ]
                    ]
                )


transactionSummaryOfferApprovedIn : Test
transactionSummaryOfferApprovedIn =
    test "transaction summary offer approved in" <|
        \() ->
            let
                model =
                    { navKey = Nothing
                    , navState = Nothing
                    , page = Home
                    , loading = Loading.Off
                    , problems = []
                    , loginForm = { email = "", password = "" }
                    , registerForm = { email = "", password = "", password_confirm = "" }
                    , session = { loginExpire = "", loginToken = "" }
                    , apiActionResponse = { status = 0, resourceId = 0, resourceIds = [] }
                    , loggedInUser = testUser1
                    , profileForm = emptyProfileForm
                    , transactionForm = emptyTransactionForm
                    , conceptForm = emptyConceptForm
                    , conceptTagForm = { tag = "" }
                    , concept = emptyConcept
                    , creatingTransaction = TxNone
                    , transactions = []
                    , pendingTransactions = []
                    , txUsers = Dict.fromList [ ( "1", testUser1 ), ( "2", testUser2 ) ]
                    , creatingTransactionWithUser = emptyUser
                    , timeZone = Time.utc
                    , time = Time.millisToPosix 0
                    , conceptsList = []
                    , conceptTagsList = []
                    , displayableTagsList = []
                    , conceptShowTagModel = Modal.hidden
                    }

                tx =
                    { id = 1
                    , initiatedDate = Time.millisToPosix 123
                    , confirmedDate = Time.millisToPosix 456
                    , fromUserId = 2
                    , toUserId = 1
                    , seconds = 3600
                    , multiplier = 1
                    , txFee = 1
                    , status = 3 --Offer Approved
                    , description = ""
                    , fromUserBalance = 3601
                    , toUserBalance = 3600
                    }
            in
            Expect.equal
                (transactionSummary model tx)
                (Table.tr
                    [ if tx.status > 4 then
                        rowAttr (style "color" "grey")

                      else
                        rowAttr (style "" "")
                    ]
                    [ Table.td [] [ text (formatDate model tx.initiatedDate) ]
                    , Table.td [] [ text "FN2 LN2 (2)" ]
                    , Table.td [] [ text "Yourself" ]
                    , Table.td [] [ text "Offer Approved" ]
                    , Table.td [] [ text (formatBalanceWithMultiplier tx.seconds tx.multiplier) ]
                    , Table.td [] [ text "" ]
                    , Table.td [] [ text (formatBalance tx.toUserBalance) ]
                    ]
                )


transactionSummaryRequestApprovedOut : Test
transactionSummaryRequestApprovedOut =
    test "transaction summary request approved out" <|
        \() ->
            let
                model =
                    { navKey = Nothing
                    , navState = Nothing
                    , page = Home
                    , loading = Loading.Off
                    , problems = []
                    , loginForm = { email = "", password = "" }
                    , registerForm = { email = "", password = "", password_confirm = "" }
                    , session = { loginExpire = "", loginToken = "" }
                    , apiActionResponse = { status = 0, resourceId = 0, resourceIds = [] }
                    , loggedInUser = testUser1
                    , profileForm = emptyProfileForm
                    , transactionForm = emptyTransactionForm
                    , conceptForm = emptyConceptForm
                    , conceptTagForm = { tag = "" }
                    , concept = emptyConcept
                    , creatingTransaction = TxNone
                    , transactions = []
                    , pendingTransactions = []
                    , txUsers = Dict.fromList [ ( "1", testUser1 ), ( "2", testUser2 ) ]
                    , creatingTransactionWithUser = emptyUser
                    , timeZone = Time.utc
                    , time = Time.millisToPosix 0
                    , conceptsList = []
                    , conceptTagsList = []
                    , displayableTagsList = []
                    , conceptShowTagModel = Modal.hidden
                    }

                tx =
                    { id = 1
                    , initiatedDate = Time.millisToPosix 123
                    , confirmedDate = Time.millisToPosix 456
                    , fromUserId = 1
                    , toUserId = 2
                    , seconds = 3600
                    , multiplier = 1
                    , txFee = 1
                    , status = 4 --Request Approved
                    , description = ""
                    , fromUserBalance = 3600
                    , toUserBalance = 3599
                    }
            in
            Expect.equal
                (transactionSummary model tx)
                (Table.tr
                    [ if tx.status > 4 then
                        rowAttr (style "color" "grey")

                      else
                        rowAttr (style "" "")
                    ]
                    [ Table.td [] [ text (formatDate model tx.initiatedDate) ]
                    , Table.td [] [ text "Yourself" ]
                    , Table.td [] [ text "FN2 LN2 (2)" ]
                    , Table.td [] [ text "Request Approved" ]
                    , Table.td [] [ text "" ]
                    , Table.td [] [ text (formatBalanceWithMultiplier tx.seconds tx.multiplier) ]
                    , Table.td [] [ text (formatBalance tx.fromUserBalance) ]
                    ]
                )


transactionSummaryRequestApprovedIn : Test
transactionSummaryRequestApprovedIn =
    test "transaction summary request approved in" <|
        \() ->
            let
                model =
                    { navKey = Nothing
                    , navState = Nothing
                    , page = Home
                    , loading = Loading.Off
                    , problems = []
                    , loginForm = { email = "", password = "" }
                    , registerForm = { email = "", password = "", password_confirm = "" }
                    , session = { loginExpire = "", loginToken = "" }
                    , apiActionResponse = { status = 0, resourceId = 0, resourceIds = [] }
                    , loggedInUser = testUser1
                    , profileForm = emptyProfileForm
                    , transactionForm = emptyTransactionForm
                    , conceptForm = emptyConceptForm
                    , conceptTagForm = { tag = "" }
                    , concept = emptyConcept
                    , creatingTransaction = TxNone
                    , transactions = []
                    , pendingTransactions = []
                    , txUsers = Dict.fromList [ ( "1", testUser1 ), ( "2", testUser2 ) ]
                    , creatingTransactionWithUser = emptyUser
                    , timeZone = Time.utc
                    , time = Time.millisToPosix 0
                    , conceptsList = []
                    , conceptTagsList = []
                    , displayableTagsList = []
                    , conceptShowTagModel = Modal.hidden
                    }

                tx =
                    { id = 1
                    , initiatedDate = Time.millisToPosix 123
                    , confirmedDate = Time.millisToPosix 456
                    , fromUserId = 2
                    , toUserId = 1
                    , seconds = 3600
                    , multiplier = 1
                    , txFee = 1
                    , status = 4 --Request Approved
                    , description = ""
                    , fromUserBalance = 3600
                    , toUserBalance = 3599
                    }
            in
            Expect.equal
                (transactionSummary model tx)
                (Table.tr
                    [ if tx.status > 4 then
                        rowAttr (style "color" "grey")

                      else
                        rowAttr (style "" "")
                    ]
                    [ Table.td [] [ text (formatDate model tx.initiatedDate) ]
                    , Table.td [] [ text "FN2 LN2 (2)" ]
                    , Table.td [] [ text "Yourself" ]
                    , Table.td [] [ text "Request Approved" ]
                    , Table.td [] [ text (formatBalanceWithMultiplier tx.seconds tx.multiplier) ]
                    , Table.td [] [ text "" ]
                    , Table.td [] [ text (formatBalance tx.toUserBalance) ]
                    ]
                )
