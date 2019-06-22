import React from 'react';
import ReactDOM from 'react-dom';
import {Provider} from 'react-redux';
import store from './store';
import {readLocalStorageForTokens} from "#app/actions";
import 'bootstrap/dist/css/bootstrap.min.css';
import {Spinner} from "#app/components/spinner";

const App = React.lazy(() => import("./app"));

const token = localStorage.getItem("token");
if (token) {
    store.dispatch(readLocalStorageForTokens());
}

ReactDOM.render(
    <Provider store={store}>
        <React.Suspense maxDuration={1000} fallback={<Spinner/>}>
            <App/>
        </React.Suspense>
    </Provider>,
    document.getElementById('app')
);

window.store = store;
