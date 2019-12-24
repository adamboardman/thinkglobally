module Transaction exposing (loadTransactions, loadTxUsers, pageTransactionList, transactionListDecoder, transactionSummary, txUsersListDecoder)

import Bootstrap.Table as Table exposing (Row, rowAttr)
import Dict exposing (Dict)
import Html exposing (Html, h4, text)
import Html.Attributes exposing (style)
import Http exposing (emptyBody)
import Json.Decode exposing (Decoder, list)
import Time
import Types exposing (ApiActionResponse, Concept, ConceptTag, Model, Msg(..), Page(..), Problem(..), Transaction, TransactionForm, TransactionFromType(..), TransactionType(..), User, ValidatedField(..), authHeader, formatBalance, formatBalancePlusFee, formatDate, transactionDecoder, userDecoder)


transactionSummary : Model -> Transaction -> Row msg
transactionSummary model tx =
    let
        date =
            if Time.posixToMillis tx.initiatedDate > 0 then
                formatDate model tx.initiatedDate

            else
                formatDate model tx.confirmedDate

        fromUser =
            Dict.get (String.fromInt tx.fromUserId) model.txUsers

        toUser =
            Dict.get (String.fromInt tx.toUserId) model.txUsers

        fromUserName =
            if model.loggedInUser.id == tx.fromUserId then
                "Yourself"

            else
                case fromUser of
                    Just user ->
                        user.firstName ++ " " ++ user.lastName ++ " (" ++ String.fromInt user.id ++ ")"

                    Nothing ->
                        " (" ++ String.fromInt tx.fromUserId ++ ")"

        toUserName =
            if model.loggedInUser.id == tx.toUserId then
                "Yourself"

            else
                case toUser of
                    Just user ->
                        user.firstName ++ " " ++ user.lastName ++ " (" ++ String.fromInt user.id ++ ")"

                    Nothing ->
                        " (" ++ String.fromInt tx.toUserId ++ ")"

        tgsIn =
            if model.loggedInUser.id == tx.toUserId then
                formatBalance tx.seconds

            else
                ""

        tgsOut =
            if model.loggedInUser.id == tx.fromUserId then
                if tx.status == 3 then
                    formatBalancePlusFee tx.seconds tx.txFee

                else
                    formatBalance tx.seconds

            else
                ""

        status =
            case tx.status of
                3 ->
                    "Offer Approved"

                4 ->
                    "Request Approved"

                5 ->
                    "Offer Rejected"

                6 ->
                    "Request Rejected"

                _ ->
                    ""

        balance =
            if model.loggedInUser.id == tx.fromUserId then
                tx.fromUserBalance

            else
                tx.toUserBalance
    in
    Table.tr
        [ if tx.status > 4 then
            rowAttr (style "color" "grey")

          else
            rowAttr (style "" "")
        ]
        [ Table.td [] [ text date ]
        , Table.td [] [ text fromUserName ]
        , Table.td [] [ text toUserName ]
        , Table.td [] [ text status ]
        , Table.td [] [ text tgsIn ]
        , Table.td [] [ text tgsOut ]
        , Table.td [] [ text (formatBalance balance) ]
        ]


pageTransactionList : Model -> List (Html Msg)
pageTransactionList model =
    [ h4 [] [ text "Recent Transactions" ]
    , Table.table
        { options = [ Table.striped, Table.hover ]
        , thead =
            Table.simpleThead
                [ Table.th [] [ text "Date" ]
                , Table.th [] [ text "From" ]
                , Table.th [] [ text "To" ]
                , Table.th [] [ text "Status" ]
                , Table.th [] [ text "TGs In" ]
                , Table.th [] [ text "TGs Out" ]
                , Table.th [] [ text "Balance" ]
                ]
        , tbody =
            Table.tbody []
                (List.map
                    (transactionSummary model)
                    model.transactions
                )
        }
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    ]



-- HTTP


loadTransactions : Model -> Cmd Msg
loadTransactions model =
    Http.request
        { method = "GET"
        , url = "/api/transactions"
        , expect = Http.expectJson LoadedTransactions transactionListDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


transactionListDecoder : Decoder (List Transaction)
transactionListDecoder =
    list transactionDecoder


loadTxUsers : Model -> Cmd Msg
loadTxUsers model =
    Http.request
        { method = "GET"
        , url = "/api/users"
        , expect = Http.expectJson LoadedTxUsers txUsersListDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


txUsersListDecoder : Decoder (List User)
txUsersListDecoder =
    list userDecoder
