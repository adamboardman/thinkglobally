import React from "react";
import {connect} from 'react-redux';
import PropTypes from 'prop-types';
import {Link} from "react-router-dom";
import 'whatwg-fetch';
import {Spinner} from "#app/components/spinner";

class UserProfile extends React.Component {
    _isMounted;

    constructor(props) {
        super(props);

        this.handleUpdateUser = this.handleUpdateUser.bind(this);
        this.updateInput = this.updateInput.bind(this);
        UserProfile.capitalizeFirstLetter = UserProfile.capitalizeFirstLetter.bind(this);

        this.state = {
            isFetching: 0,
            error: '',
            loadedUser: false,
            userId: 0,
            firstName: '',
            midNames: '',
            lastName: '',
            location: '',
            email: '',
            photoId: 0,
        };
    }

    componentDidMount() {
        this._isMounted = true;
        const headers = new Headers({"Authorization": "Bearer " + this.props.loginToken});
        this.loadUser(this.state.userId, headers);
    }

    componentWillUnmount() {
        this._isMounted = false;
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

    userLoaded(json) {
        if (!this._isMounted) return;
        this.setState({
            userId: json.ID,
            firstName: json.FirstName,
            midNames: json.MidNames,
            lastName: json.LastName,
            location: json.Location,
            email: json.Email,
            mobile: json.Mobile,
            photoId: json.PhotoID,
            loadedUser: true,
        });
    }

    onPhotoIdChange(photoId) {
        this.setState({
            photoId: photoId,
        });
    }

    loadUser(id, header) {
        this.fetching(true);

        fetch('/api/users/' + id, {method: 'GET', headers: header})
            .then(
                (response) => {
                    if (!response.ok) {
                        throw Error(response.statusText);
                    }
                    return response.json();
                })
            .then((json) => {
                this.userLoaded(json);
                this.fetching(false);
            })
            .catch((err) => {
                this.fetchError(err);
                this.fetching(false);
            });
    }

    updateUser(id, header, data) {
        this.fetching(true);

        fetch('/api/users/' + id, {method: 'PUT', headers: header, body: data})
            .then(
                (response) => {
                    if (!response.ok) {
                        throw Error(response.statusText);
                    }
                    return response.json();
                })
            .then(() => {
                this.loadUser(id, header);
                this.fetching(false);
            })
            .catch((err) => {
                this.fetchError(err);
                this.fetching(false);
            });
    }

    updateInput(event) {
        if (!this._isMounted) return;
        let value = event.target.value;
        if (event.target.type === "checkbox") {
            value = event.target.checked;
        }
        this.setState({
            [event.target.name]: value,
            WillEat: '',
        });
    }

    handleUpdateUser(event) {
        event.preventDefault();
        if (!event.target.checkValidity()) {
            event.target.classList.add('was-validated');
            return;
        }
        const userData = {
            FirstName: this.state.firstName,
            MidNames: this.state.midNames,
            LastName: this.state.lastName,
            Location: this.state.location,
            Email: this.state.email,
            Mobile: this.state.mobile,
        };
        const data = JSON.stringify(userData);
        const headers = new Headers({"Authorization": "Bearer " + this.props.loginToken});
        headers.append("Content-Type", "application/json");

        if (this.state.userId) {
            this.updateUser(this.state.userId, headers, data);
        }
    }

    static capitalizeFirstLetter(string) {
        return string.charAt(0).toUpperCase() + string.slice(1);
    }

    render() {
        const isFetching = this.state.isFetching;
        const userId = this.state.userId;
        const photoId = this.state.photoId;

        return (
            <div className="container">
                <div className="col-lg-12 jumbotron">
                    <h1>Edit profile</h1>
                    {this.state.loadedUser === false ? (
                        <Spinner/>
                    ) : (
                        <form onSubmit={this.handleUpdateUser} noValidate>
                            <div className="form-group">
                                <label htmlFor="name">First Name</label>
                                <input
                                    type="text" className="form-control" id="firstName" name="firstName"
                                    value={this.state.firstName}
                                    onChange={evt => this.updateInput(evt)}
                                    placeholder="Enter first name" required/>
                                <div className="invalid-feedback">
                                    Please enter your first name.
                                </div>
                            </div>
                            <div className="form-group">
                                <label htmlFor="place">Mid Names</label>
                                <input
                                    type="text" className="form-control" id="midNames" name="midNames"
                                    value={this.state.midNames}
                                    onChange={evt => this.updateInput(evt)}
                                    placeholder="Please enter the middle names"/>
                            </div>
                            <div className="form-group">
                                <label htmlFor="place">Last Name</label>
                                <input
                                    type="text" className="form-control" id="lastName" name="lastName"
                                    value={this.state.lastName}
                                    onChange={evt => this.updateInput(evt)}
                                    placeholder="Please enter the last name"/>
                                <div className="invalid-feedback">
                                    Please enter your last name.
                                </div>
                            </div>
                            <div className="form-group">
                                <label htmlFor="place">Home location for display on your profile</label>
                                <input
                                    type="text" className="form-control" id="location" name="location"
                                    value={this.state.location}
                                    onChange={evt => this.updateInput(evt)}
                                    placeholder="Please enter your location"/>
                            </div>
                            <div className="form-group">
                                <label htmlFor="place">Email</label>
                                <input
                                    type="text" className="form-control" id="email" name="email"
                                    value={this.state.email}
                                    onChange={evt => this.updateInput(evt)}
                                    placeholder="Please enter your email address" required/>
                                <div className="invalid-feedback">
                                    Please enter your email address.
                                </div>
                            </div>
                            <div className="form-group">
                                <label htmlFor="place">Mobile</label>
                                <input
                                    type="text" className="form-control" id="mobile" name="mobile"
                                    value={this.state.mobile}
                                    onChange={evt => this.updateInput(evt)}
                                    placeholder="Please enter your mobile number"/>
                            </div>
                            <div>
                                {"" + this.state.error}
                            </div>
                            <button className="btn btn-primary" disabled={this.state.isFetching}>
                                {
                                    isFetching
                                        ? "In progress"
                                        : "Save Profile"
                                }
                            </button>
                        </form>
                    )}
                    <p>Or</p>
                    <Link to="/concepts" className="btn btn-primary">Back</Link>
                </div>
            </div>
        );
    }
}

UserProfile.propTypes = {
    loginToken: PropTypes.string,
};

const mapUsersStateToProps = (state) => {
    return {
        loginToken: state.loginToken,
    };
};

export default connect(mapUsersStateToProps)(UserProfile);
