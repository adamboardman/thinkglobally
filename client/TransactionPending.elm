module TransactionPending exposing (acceptTransaction, pageTransactionPending, pendingTransactionSummary, rejectTransaction)

import Bootstrap.Button as Button
import Bootstrap.Table as Table exposing (Row)
import Dict exposing (Dict)
import FormatNumber exposing (format)
import Html exposing (Html, h4, text)
import Http exposing (emptyBody)
import Json.Decode exposing (Decoder, list)
import Time
import Types exposing (ApiActionResponse, Concept, ConceptTag, Model, Msg(..), Page(..), Problem(..), Transaction, TransactionForm, TransactionFromType(..), TransactionType(..), User, ValidatedField(..), apiActionDecoder, authHeader, formatBalance, formatDate, tgsLocale, transactionDecoder, userDecoder)


pendingTransactionSummary : Model -> Transaction -> Row Msg
pendingTransactionSummary model tx =
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
                        String.fromInt tx.fromUserId

        toUserName =
            if model.loggedInUser.id == tx.toUserId then
                "Yourself"

            else
                case toUser of
                    Just user ->
                        user.firstName ++ " " ++ user.lastName ++ " (" ++ String.fromInt user.id ++ ")"

                    Nothing ->
                        String.fromInt tx.toUserId

        tgsAsSeconds =
            case tx.status of
                1 ->
                    if tx.fromUserId == model.loggedInUser.id then
                        tx.seconds + tx.txFee

                    else
                        tx.seconds

                2 ->
                    if tx.toUserId == model.loggedInUser.id then
                        tx.seconds - tx.txFee

                    else
                        tx.seconds

                _ ->
                    0

        tgs =
            if tx.fromUserId == model.loggedInUser.id then
                toFloat -tgsAsSeconds / 3600

            else
                toFloat tgsAsSeconds / 3600

        newBalanceFrom =
            case ( fromUser, tx.status ) of
                ( Just user, 1 ) ->
                    user.balance - round (toFloat tx.seconds + toFloat tx.txFee)

                ( Just user, 2 ) ->
                    user.balance - round (toFloat tx.seconds)

                _ ->
                    0

        newBalanceTo =
            case ( toUser, tx.status ) of
                ( Just user, 1 ) ->
                    user.balance + round (toFloat tx.seconds)

                ( Just user, 2 ) ->
                    user.balance + round (toFloat tx.seconds - toFloat tx.txFee)

                _ ->
                    0

        status =
            case tx.status of
                1 ->
                    if tx.fromUserId == model.loggedInUser.id then
                        "Offer pending"

                    else
                        "Accept or Reject Offer"

                2 ->
                    if tx.toUserId == model.loggedInUser.id then
                        "Request pending"

                    else
                        "Accept or Reject Request"

                _ ->
                    ""
    in
    Table.tr []
        [ Table.td [] [ text date ]
        , Table.td [] [ text "F: ", text fromUserName, Html.br [] [], text "T: ", text toUserName ]
        , Table.td [] [ text (format tgsLocale tgs) ]
        , Table.td [] [ text "F: ", text (formatBalance newBalanceFrom), Html.br [] [], text "T: ", text (formatBalance newBalanceTo) ]
        , Table.td [] [ text status ]
        , Table.td []
            [ if (tx.status == 1 && tx.toUserId == model.loggedInUser.id) || (tx.status == 2 && tx.fromUserId == model.loggedInUser.id) then
                Button.button [ Button.primary, Button.onClick <| AcceptTransaction tx.id ] [ text "Accept" ]

              else
                text ""
            ]
        , Table.td []
            [ if (tx.status == 1 && tx.toUserId == model.loggedInUser.id) || (tx.status == 2 && tx.fromUserId == model.loggedInUser.id) then
                Button.button [ Button.primary, Button.onClick <| RejectTransaction tx.id ] [ text "Reject" ]

              else
                text ""
            ]
        ]


pageTransactionPending : Model -> List (Html Msg)
pageTransactionPending model =
    [ h4 [] [ text "Pending Transactions" ]
    , Table.table
        { options = [ Table.striped, Table.hover ]
        , thead =
            Table.simpleThead
                [ Table.th [] [ text "Date" ]
                , Table.th [] [ text "Parties" ]
                , Table.th [] [ text "TGs" ]
                , Table.th [] [ text "New Balances" ]
                , Table.th [] [ text "Status" ]
                , Table.th [] [ text "" ]
                , Table.th [] [ text "" ]
                ]
        , tbody =
            Table.tbody []
                (List.map
                    (pendingTransactionSummary model)
                    model.pendingTransactions
                )
        }
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    , Html.br [] []
    ]



-- HTTP


acceptTransaction : Model -> Int -> Cmd Msg
acceptTransaction model txId =
    Http.request
        { method = "PATCH"
        , url = "/api/transactions/" ++ String.fromInt txId ++ "/accept"
        , expect = Http.expectJson AcceptedTransaction apiActionDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


rejectTransaction : Model -> Int -> Cmd Msg
rejectTransaction model txId =
    Http.request
        { method = "PATCH"
        , url = "/api/transactions/" ++ String.fromInt txId ++ "/reject"
        , expect = Http.expectJson RejectedTransaction apiActionDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }
