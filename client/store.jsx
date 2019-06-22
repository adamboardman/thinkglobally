import {createLogger} from 'redux-logger';
import {applyMiddleware, createStore} from "redux";
import thunkMiddleware from "redux-thunk";
import reducers, {initialState} from './reducers';

const middleware = [thunkMiddleware];
if (process.env.NODE_ENV !== 'production') {
    middleware.push(createLogger());
}

const store = createStore(
    reducers,
    initialState,
    applyMiddleware(...middleware)
);

export default store;