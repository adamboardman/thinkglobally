import React from "react";
import {connect} from 'react-redux';
import {BrowserRouter, Link, Redirect, Route, Switch} from "react-router-dom";
import PropTypes from 'prop-types';
import {
    Collapse,
    DropdownItem,
    DropdownMenu,
    DropdownToggle,
    Nav,
    Navbar,
    NavbarBrand,
    NavbarToggler,
    NavItem,
    NavLink,
    UncontrolledDropdown
} from "reactstrap";
import {logout} from "#app/actions";
import Login from "./login";
import Register from "./register";
import UserProfile from "./userprofile";
import Concept from "./concept";
import ConceptsList from "./conceptslist";
import ConceptAdd from "./conceptadd";
import ConceptEdit from "./conceptedit";

const AuthOnlyRoute = ({component: Component, loginToken, ...rest}) => (
    <Route {...rest} render={(props) => (
        loginToken.length > 0
            ? <Component {...props} />
            : <Redirect to={{
                pathname: '/login',
                state: {from: props.location}
            }}/>
    )}/>
);

class App extends React.Component {
    constructor(props) {
        super(props);

        this.logout = this.logout.bind(this);
        this.toggle = this.toggle.bind(this);
        this.state = {
            isOpen: false
        };
    }

    logout() {
        this.props.logout();
        location.reload();
    }

    toggle() {
        this.setState({
            isOpen: !this.state.isOpen
        });
    }

    render() {
        const {loginToken} = this.props;
        return (
            <BrowserRouter>
                <div className="container-fluid">
                    <Navbar color="light" light expand="md">
                        <NavbarBrand tag={Link} to="/">ThinkGlobally</NavbarBrand>
                        <NavbarToggler onClick={this.toggle}/>
                        <Collapse isOpen={this.state.isOpen} navbar>
                            <Nav className="ml-auto" navbar>
                                {loginToken.length > 0 &&
                                <NavItem>
                                    <NavLink tag={Link} to="/concepts">Concepts</NavLink>
                                </NavItem>
                                }
                                {loginToken.length > 0 &&
                                <UncontrolledDropdown nav inNavbar>
                                    <DropdownToggle nav caret>
                                        <span className="glyphicon glyphicon-plus" aria-hidden="true"/>
                                        Add
                                    </DropdownToggle>
                                    <DropdownMenu right>
                                        <DropdownItem tag={Link} to="/add_concept">Concept</DropdownItem>
                                    </DropdownMenu>
                                </UncontrolledDropdown>
                                }
                                {loginToken.length > 0 &&
                                <NavItem>
                                    <NavLink tag={Link} to="/profile">
                                        <span className="glyphicon glyphicon-user" aria-hidden="true"/>User
                                    </NavLink>
                                </NavItem>
                                }
                                <NavItem>
                                    {loginToken.length > 0 &&
                                    <NavLink onClick={this.logout}>Logout</NavLink>
                                    }
                                    {loginToken.length === 0 &&
                                    <NavLink tag={Link} to="/login">Login</NavLink>
                                    }
                                </NavItem>
                            </Nav>
                        </Collapse>
                    </Navbar>
                    <Switch>
                        <Route exact path="/login" component={Login}/>
                        <Route exact path="/register" component={Register}/>
                        <Route exact path="/add_concept" render={() => (
                            loginToken.length > 0 ? (
                                <ConceptAdd/>
                            ) : (
                                <Redirect to="/"/>
                            )
                        )}/>
                        <Route exact path="/profile" render={() => (
                            loginToken.length > 0 ? (
                                <UserProfile/>
                            ) : (
                                <Redirect to="/"/>
                            )
                        )}/>
                        <Route exact path="/" component={Concept}/>
                        <AuthOnlyRoute exact path="/concepts/:id/edit" loginToken={loginToken} component={ConceptEdit}/>
                        <AuthOnlyRoute exact path="/concepts" loginToken={loginToken} component={ConceptsList}/>
                        <Route exact path="/concept/:tag" component={Concept}/>
                    </Switch>
                </div>
            </BrowserRouter>
        );
    }
}

App.propTypes = {
    isFetching: PropTypes.number,
    loginToken: PropTypes.string,
    lastUpdated: PropTypes.number,
    emailConfirmed: PropTypes.bool,
    concepts: PropTypes.array,
    photos: PropTypes.array,
    logout: PropTypes.func.isRequired,
};

const mapAppStateToProps = (state) => {
    return {
        isFetching: state.isFetching,
        loginToken: state.loginToken,
        lastUpdated: state.lastUpdated,
        emailConfirmed: state.emailConfirmed,
    };
};

const mapAppDispatchToProps = (dispatch) => {
    return {
        logout: () => dispatch(logout())
    };
};

export default connect(mapAppStateToProps, mapAppDispatchToProps)(App);
