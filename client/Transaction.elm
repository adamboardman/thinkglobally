module Transaction exposing (loadTransactions, loadTxUsers, pageTransactionList, transactionListDecoder, transactionSummary, txUsersListDecoder)

import Bootstrap.Button as Button
import Bootstrap.Table as Table exposing (Row, rowAttr)
import Html exposing (Html, h4, text)
import Html.Attributes exposing (style)
import Http exposing (emptyBody)
import Json.Decode exposing (Decoder, list)
import Types exposing (ApiActionResponse, Concept, ConceptTag, Model, Msg(..), Page(..), Problem(..), Transaction, TransactionForm, TransactionFromType(..), TransactionType(..), User, ValidatedField(..), authHeader, formatBalance, formatBalancePlusFee, formatDate, transactionDecoder, userDecoder)


transactionSummary : Model -> Transaction -> Row Msg
transactionSummary model tx =
    let
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
        [ Table.td [] [ text (Types.dateFromTransaction model tx) ]
        , Table.td [] [ text (Types.transactionFromUserName model tx) ]
        , Table.td [] [ text (Types.transactionToUserName model tx) ]
        , Table.td [] [ text (Types.transactionStatus model tx) ]
        , Table.td [] [ text tgsIn ]
        , Table.td [] [ text tgsOut ]
        , Table.td [] [ text (formatBalance balance) ]
        , Table.td [] [ Button.button [ Button.primary, Button.onClick <| ViewTransaction tx.id ] [ text "View" ] ]
        ]


pageTransactionList : Model -> List (Html Msg)
pageTransactionList model =
    List.concat
        [ [ h4 [] [ text "Recent Transactions" ]
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
                        , Table.th [] [ text "View" ]
                        ]
                , tbody =
                    Table.tbody []
                        (List.map
                            (transactionSummary model)
                            model.transactions
                        )
                }
          , Html.br [] []
          ]
        , Types.transactionDetailedSummary model model.transactions
        , [ Html.br [] []
          , Html.br [] []
          , Html.br [] []
          , Html.br [] []
          ]
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
