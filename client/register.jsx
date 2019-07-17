import React from "react";
import 'whatwg-fetch';

export default class Register extends React.Component {
    constructor(props) {
        super(props);

        this.handleRegister = this.handleRegister.bind(this);

        this.state = {
            isFetching: 0,
            error: '',
            registered: false,
            loginExpire: '',
            loginToken: '',
        };
    }

    fetching(fetching) {
        this.setState({
            isFetching: this.state.isFetching + (fetching ? 1 : -1)
        });
    }

    fetchError(error) {
        this.setState({
            error: error,
        });
    }

    handleRegister(event) {
        event.preventDefault();
        if (!event.target.checkValidity()) {
            event.target.classList.add('was-validated');
            return;
        }
        let data = new FormData(event.target);

        this.register(data);
    }

    register(data) {
        this.fetching(true);
        this.fetchError('');

        fetch('/api/auth/register', {method: 'POST', body: data})
            .then(
                (response) => {
                    if (!response.ok) {
                        throw Error(response.statusText);
                    }
                    return response.json();
                })
            .then((json) => {
                this.userRegistered(json);
                this.fetching(false);
            })
            .catch((err) => {
                this.fetchError(err);
                this.fetching(false);
            });
    }

    userRegistered(json) {
        this.setState({
            registered: true,
            loginExpire: json.expire,
            loginToken: json.token,
        });
    }

    render() {
        return (
            <div className="container">
                <div className="col-xs-8 col-xs-offset-2 jumbotron">
                    {this.state.registered ? (<div>
                        <p>Thanks for registering, please check your email for the confirmation link.</p>
                    </div>) : (<div>
                        <p>Think Globally - Trade Locally - TG&apos;s - Semi-distributed digital time banking</p>
                        <p>Register to get access</p>
                        <form onSubmit={this.handleRegister} noValidate>
                            <div className="form-group">
                                <label htmlFor="email">Enter your email</label>
                                <input id="email" name="email" type="email" className="form-control" required/>
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
                            <div className="form-group">
                                <label htmlFor="password_confirmation">Confirm your password</label>
                                <input
                                    id="password_confirmation" name="password_confirmation" type="password"
                                    className="form-control" required/>
                                <div className="invalid-feedback">
                                    Please enter the same password again
                                </div>
                            </div>
                            <div>
                                {"" + this.state.error}
                            </div>
                            <button
                                className="btn btn-primary btn-lg btn-login btn-block" disabled={this.state.isFetching}>
                                {
                                    this.state.isFetching
                                        ? "In progress"
                                        : "Register"
                                }
                            </button>
                        </form>
                    </div>)}
                </div>
            </div>
        );
    }
}
