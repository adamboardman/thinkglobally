module TransactionPending exposing (acceptTransaction, pageTransactionPending, pendingTransactionSummary, rejectTransaction)

import Bootstrap.Button as Button
import Bootstrap.Table as Table exposing (Row)
import FormatNumber exposing (format)
import Html exposing (Html, h4, text)
import Http exposing (emptyBody)
import Types exposing (ApiActionResponse, Concept, ConceptTag, Model, Msg(..), Page(..), Problem(..), Transaction, TransactionForm, TransactionFromType(..), TransactionType(..), User, ValidatedField(..), apiActionDecoder, authHeader, formatBalance, tgsLocale)


pendingTransactionSummary : Model -> Transaction -> Row Msg
pendingTransactionSummary model tx =
    Table.tr []
        [ Table.td [] [ text (Types.dateFromTransaction model tx) ]
        , Table.td [] [ text "F: ", text (Types.transactionFromUserName model tx), Html.br [] [], text "T: ", text (Types.transactionToUserName model tx) ]
        , Table.td [] [ text (format tgsLocale (Types.tgsFromTransaction model tx)) ]
        , Table.td [] [ text "F: ", text (formatBalance (Types.transactionNewBalanceFrom model tx)), Html.br [] [], text "T: ", text (formatBalance (Types.transactionNewBalanceTo model tx)) ]
        , Table.td [] [ text (Types.transactionStatus model tx) ]
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
        , Table.td [] [ Button.button [ Button.primary, Button.onClick <| ViewTransaction tx.id ] [ text "View" ] ]
        ]


transactionDetailedSummary : Model -> List Transaction -> List (Html Msg)
transactionDetailedSummary model txs =
    case List.head (List.filter (Types.isSelectedTx model.selectedTxId) txs) of
        Just tx ->
            [ Html.div [] [ text "Date: ", text (Types.dateFromTransaction model tx) ]
            , Html.div [] [ text "From: ", text (Types.transactionFromUserName model tx) ]
            , Html.div [] [ text "To: ", text (Types.transactionToUserName model tx) ]
            , Html.div [] [ text "Value in TGs: ", text (format tgsLocale (Types.tgsFromTransaction model tx)) ]
            , Html.div []
                [ text "Resultant Balances: "
                , text (Types.transactionFromUserName model tx)
                , text ": "
                , text (formatBalance (Types.transactionNewBalanceFrom model tx))
                , text ", "
                , text (Types.transactionToUserName model tx)
                , text ": "
                , text (formatBalance (Types.transactionNewBalanceTo model tx))
                ]
            , Html.div [] [ text "Status: ", text (Types.transactionStatus model tx) ]
            , Html.div [] [ text "Description: ", text tx.description ]
            ]

        Nothing ->
            [ Html.div []
                [ text "No transaction selected for detailed view"
                ]
            ]


pageTransactionPending : Model -> List (Html Msg)
pageTransactionPending model =
    List.concat
        [ [ h4 [] [ text "Pending Transactions" ]
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
          ]
        , transactionDetailedSummary model model.pendingTransactions
        , [ Html.br [] []
          , Html.br [] []
          , Html.br [] []
          , Html.br [] []
          ]
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
