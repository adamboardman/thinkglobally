import React from "react";
import {addConcept, addConceptTag, deleteConceptTag, loadConcept, updateConcept} from "#app/actions";
import {connect} from 'react-redux';
import PropTypes from 'prop-types';
import {Modal, ModalBody, ModalFooter, ModalHeader} from "reactstrap";

class ConceptEditContent extends React.Component {
    constructor(props) {
        super(props);

        this.handleUpdateConcept = this.handleUpdateConcept.bind(this);
        this.handleShowTagModal = this.handleShowTagModal.bind(this);
        this.handleHideTagModal = this.handleHideTagModal.bind(this);
        this.handleAddConceptTag = this.handleAddConceptTag.bind(this);
        this.handleDeleteConceptTag = this.handleDeleteConceptTag.bind(this);

        this.state = {
            showTagModal: false,
            inputId: this.props.concept ? this.props.concept.ID : 0,
            inputName: this.props.concept ? this.props.concept.Name : '',
            inputSummary: this.props.concept ? this.props.concept.Summary : '',
            inputFull: this.props.concept ? this.props.concept.Full : '',
            inputTag: '',
            conceptTagsToDelete: [],
        };
    }

    updateInputValueName(event) {
        this.setState({
            inputName: event.target.value
        });
    }

    updateInputValueNewTag(event) {
        this.setState({
            inputTag: event.target.value
        });
    }

    updateInputValueSummary(event) {
        this.setState({
            inputSummary: event.target.value
        });
    }

    updateInputValueFull(event) {
        this.setState({
            inputFull: event.target.value
        });
    }

    updateInputValueTagDelete(event) {
        let newTagDeletion = this.state.conceptTagsToDelete;
        if (newTagDeletion === undefined) {
            newTagDeletion = [];
        }
        if (event.target.checked) {
            newTagDeletion.push(event.target.value);
        } else {
            let index = newTagDeletion.indexOf(event.target.value);
            newTagDeletion.splice(index, 1);
        }
        this.setState({
            conceptTagsToDelete: newTagDeletion
        });
    }

    handleUpdateConcept(event) {
        event.preventDefault();
        if (!event.target.checkValidity()) {
            event.target.classList.add('was-validated');
            return;
        }
        const userData = {
            ID: this.state.inputId,
            Name: this.state.inputName,
            Summary: this.state.inputSummary,
            Full: this.state.inputFull,
        };
        const data = JSON.stringify(userData);

        const headers = new Headers({"Authorization": "Bearer " + this.props.loginToken});
        if (this.props.concept) {
            this.props.updateConcept(this.props.concept.ID, headers, data);
        } else {
            this.props.addConcept(headers, data);
        }
    }

    handleShowTagModal() {
        this.setState({showTagModal: true});
    }

    handleHideTagModal() {
        this.setState({showTagModal: false});
    }

    handleAddConceptTag(event) {
        event.preventDefault();
        if (!event.target.checkValidity()) {
            event.target.classList.add('was-validated');
            return;
        }
        const userData = {
            ConceptId: this.props.concept.ID,
            Tag: this.state.inputTag,
        };
        const data = JSON.stringify(userData);

        const headers = new Headers({"Authorization": "Bearer " + this.props.loginToken});
        this.props.addConceptTag(headers, data);
        this.handleHideTagModal();
    }

    handleDeleteConceptTag(event) {
        event.preventDefault();
        const headers = new Headers({"Authorization": "Bearer " + this.props.loginToken});
        for (let i = 0; i < this.state.conceptTagsToDelete.length; i++) {
            this.props.deleteConceptTag(headers, this.state.conceptTagsToDelete[i]);
        }
    }

    render() {
        const concept = this.props.concept;
        const isFetching = this.props.isFetching;

        return (
            <div>
                <form onSubmit={this.handleUpdateConcept} noValidate>
                    <div className="form-group">
                        <label htmlFor="name">Concept Name</label>
                        <input
                            type="text" className="form-control" id="name" name="name"
                            defaultValue={concept ? concept.Name : ''}
                            onChange={evt => this.updateInputValueName(evt)}
                            placeholder="Enter name" required/>
                    </div>
                    <fieldset className="form-group">
                        <label>Tags</label>
                        <div className="row">
                            <div className="col-sm-10">
                                {concept && concept.Tags != null ? concept.Tags.map((tag) => {
                                    return (
                                        <label key={tag.ID} className="form-check form-check-inline">
                                            <input
                                                type="checkbox" name="tags" id={tag.ID} value={tag.ID}
                                                onChange={evt => this.updateInputValueTagDelete(evt)}
                                            />
                                            {tag.Tag}
                                        </label>
                                    );
                                }) : (<div></div>)}
                            </div>
                        </div>
                    </fieldset>
                    <div className="form-group">
                        {concept && concept.ID > 0 ? (
                            <div className="row">
                                <button
                                    type="button" className="btn btn-secondary" onClick={this.handleShowTagModal}>
                                    Add Tag
                                </button>
                                <button
                                    type="button" className="btn btn-secondary" onClick={this.handleDeleteConceptTag}>
                                    Delete Tag
                                </button>
                            </div>
                        ) : (
                            <div className="row">
                                <p>Must save concept before adding tags</p>
                            </div>
                        )}
                    </div>
                    <div className="form-group">
                        <label htmlFor="summary">Summary</label>
                        <textarea
                            className="form-control" rows="3" name="summary" id="summary"
                            onChange={evt => this.updateInputValueSummary(evt)}
                            defaultValue={concept ? concept.Summary : ''}/>
                    </div>
                    <div className="form-group">
                        <label htmlFor="full">Full</label>
                        <textarea
                            className="form-control" rows="3" name="full" id="full"
                            onChange={evt => this.updateInputValueFull(evt)}
                            defaultValue={concept ? concept.Full : ''}/>
                    </div>
                    <button className="btn btn-primary" disabled={isFetching}>
                        {
                            isFetching
                                ? "In progress"
                                : "Save Concept"
                        }
                    </button>
                </form>
                <Modal isOpen={this.state.showTagModal} toggle={this.handleHideTagModal}>
                    <ModalHeader>Add Concept Tag</ModalHeader>
                    <ModalBody>
                        <form onSubmit={this.handleAddConceptTag} noValidate className="form-horizontal">
                            <div className="form-group">
                                <label htmlFor="tagTag">Tag</label>
                                <input
                                    type="text" className="form-control" id="tagTag" name="tagTag"
                                    onChange={evt => this.updateInputValueNewTag(evt)}
                                    placeholder="Enter tag" required/>
                            </div>
                            <button className="btn btn-primary">
                                Add tag
                            </button>
                        </form>
                    </ModalBody>
                    <ModalFooter>
                        <button className="btn btn-secondary" onClick={this.handleHideTagModal}>Close</button>
                    </ModalFooter>
                </Modal>
            </div>
        );
    }
}

ConceptEditContent.propTypes = {
    isFetching: PropTypes.number,
    loginToken: PropTypes.string,
    addConcept: PropTypes.func.isRequired,
    updateConcept: PropTypes.func.isRequired,
    addConceptTag: PropTypes.func.isRequired,
    deleteConceptTag: PropTypes.func.isRequired,
    concept: PropTypes.object,
};

const mapStateToContentProps = (state) => {
    return {
        isFetching: state.isFetching,
        loginToken: state.loginToken,
        lastUpdated: state.lastUpdated,
        emailConfirmed: state.emailConfirmed,
        concept: state.concept,
    };
};

const mapDispatchToContentProps = (dispatch) => {
    return {
        loadConcept: (conceptId, headers) => dispatch(loadConcept(conceptId, headers)),
        addConcept: (headers, conceptInfo) => dispatch(addConcept(headers, conceptInfo)),
        updateConcept: (conceptId, headers, conceptInfo) => dispatch(updateConcept(conceptId, headers, conceptInfo)),
        addConceptTag: (headers, conceptTagInfo) => dispatch(addConceptTag(headers, conceptTagInfo)),
        deleteConceptTag: (headers, conceptTagId) => dispatch(deleteConceptTag(headers, conceptTagId)),
    };
};

export default connect(mapStateToContentProps, mapDispatchToContentProps)(ConceptEditContent);
