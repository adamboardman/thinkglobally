import React from "react";
import {login} from "#app/actions";
import {Link, Redirect} from "react-router-dom";
import {connect} from 'react-redux';
import PropTypes from 'prop-types';

class Login extends React.Component {
    constructor(props) {
        super(props);

        this.handleLogin = this.handleLogin.bind(this);
    }

    handleLogin(event) {
        event.preventDefault();
        if (!event.target.checkValidity()) {
            event.target.classList.add('was-validated');
            return;
        }

        let data = new FormData(event.target);

        this.props.doLogin(data);
    }

    render() {
        const {isFetching, loginToken, location} = this.props;
        if (loginToken.length > 0) {
            return (<Redirect to={location.state ? location.state.from : '/'}/>);
        }
        return (
            <div className="container">
                <div className="col-xs-8 col-xs-offset-2 jumbotron">
                    <h1>ThinkGlobally - trade locally</h1>
                    <p>A time based trading system</p>
                    <p>Sign in to get access </p>
                    <form onSubmit={this.handleLogin} noValidate>
                        <div className="form-group">
                            <label htmlFor="email">Enter your email</label>
                            <input
                                placeholder="Your email address" id="email" name="email" type="email"
                                className="form-control" required/>
                            <div className="invalid-feedback">
                                Please enter your email address
                            </div>
                        </div>
                        <div className="form-group">
                            <label htmlFor="password">Enter your password</label>
                            <input id="password" name="password" type="password" className="form-control" required/>
                            <div className="invalid-feedback">
                                Please enter your password
                            </div>
                        </div>
                        <div>{"" + this.props.error}</div>
                        <button className="btn btn-primary btn-lg btn-login btn-block" disabled={isFetching}>
                            {
                                isFetching
                                    ? "In progress"
                                    : "Sign In"
                            }
                        </button>
                    </form>
                    <p>Or</p>
                    <Link to="/register" className="btn btn-primary btn-lg btn-login btn-block">Register</Link>
                </div>
            </div>
        );
    }
}

Login.propTypes = {
    doLogin: PropTypes.func.isRequired,
    isFetching: PropTypes.number,
    error: PropTypes.string,
    loginToken: PropTypes.string,
    emailConfirmed: PropTypes.bool,
};

const mapStateToProps = (state) => {
    return {
        isFetching: state.isFetching,
        error: state.error,
        loginToken: state.loginToken,
        emailConfirmed: state.emailConfirmed
    };
};

const mapDispatchToProps = (dispatch) => {
    return {
        doLogin: (data) => dispatch(login(data)),
    };
};

export default connect(mapStateToProps, mapDispatchToProps)(Login);
