/* eslint-disable @lwc/lwc/no-async-operation */
/* eslint-disable dot-notation */

import { LightningElement, track, api } from "lwc";
import getFieldForUserStory from "@salesforce/apex/FilterComponentController.getFields";
import filterUSerStory from "@salesforce/apex/FilterComponentController.filterUserStoryRecord";
import DataProcessor from "./dataProcessor";
import { handleAsyncError } from "c/copadocoreUtils";
import ERROR from "@salesforce/label/c.ERROR";

const SEARCH_EVENT = "search";
const CLEAR_SEARCH_EVENT = "clearsearch";
const DEFAULT_FILTER_EVENT = "defaultfilter";
export default class FilterComponent extends LightningElement {
  @api recordId;
  @api fieldset;
  @api recordLimit;
  @track fieldList;
  @track fieldRelatedToUserStory = [];
  @track filterList = [];

  fieldSelected = "Acceptance_Criteria__c";
  fieldLabelSelected = "Acceptance Criteria";
  operatorLabelSelected = "Equal";
  operatorSelected = "=";
  valueSelected;

  isCheckbox;
  isPicklist;
  showCancelAndSave = false;
  isText = true;
  showOwnerFilter = false;
  fieldTypeMap = new Map();
  fieldAndItsPicklistValues = new Map();
  picklistValue = [];
  picklistOption = [];
  ownerValue = "All User Stories";
  ownerSelected = "All User Stories";

  modes = {
    EDIT: "edit",
    NEW: "new"
  };

  _isOpen = false;
  _showPopover = false;
  _scrollEventCallback;

  get options() {
    return [
      { label: "Equal", value: "=" },
      { label: "Not Equal", value: "!=" },
      { label: "Less Than", value: "<" },
      { label: "Greater Than", value: ">" },
      { label: "Less Than or Equal", value: "<=" },
      { label: "Greater Than or Equal", value: ">=" },
      { label: "Contains", value: "Like" },
      { label: "Does Not Contains", value: "!Like" },
      { label: "Starts With", value: "StartsWith" }
    ];
  }

  get istrueoptions() {
    return [
      { label: "True", value: "True" },
      { label: "False", value: "False" }
    ];
  }

  get ownerOptions() {
    return [
      { label: "All User Stories", value: "All User Stories" },
      { label: "My User Stories", value: "My User Stories" }
    ];
  }

  showFilters() {
    const el = this.template.querySelector(".collapsible-filter");
    const filterContainerElem = this.template.querySelector(
      ".filter-container"
    );

    this._isOpen = !this._isOpen;

    if (this._isOpen) {
      el.classList.remove("collapsed");
      el.classList.add("expanded");

      // calculates container height
      setTimeout(() => {
        filterContainerElem.style.height = `${el.clientHeight - 5}px`;
      }, 0);
    } else {
      el.classList.remove("expanded");
      el.classList.add("collapsed");

      this.closeAllPopovers();
      this.showOwnerFilter = false;

      // remove listener
      filterContainerElem.removeEventListener(
        "scroll",
        this._scrollEventCallback
      );
    }
  }

  scrollEventCallback(eventData, event) {
    // Recalculates popover position depending on scroll
    const template = eventData.elem;
    const popoverTopCalculation = eventData.newTopCalculation;
    const scroll = event.target.scrollTop;
    const popElem = template.querySelector(".vsm-popover");

    if (popElem) {
      //const calculatedTopValue = popoverTopCalculation - scroll < 0 ? 0 : popoverTopCalculation - scroll;
      const calculatedTopValue = popoverTopCalculation - scroll;

      popElem.style.top = `${calculatedTopValue}px`;
    }
  }

  toggleOwner() {
    this.closeAllPopovers();
    this.showOwnerFilter = !this.showOwnerFilter;

    setTimeout(() => {
      let filterContainerElem, filterContainerElemScrollTop;
      let filterElem, filterElemHeight, filterElemOffsetTop;
      let popoverElem, popoverHeight;
      let popoverTopCalculation;

      filterContainerElem = this.template.querySelector(".filter-container");
      filterContainerElemScrollTop = filterContainerElem.scrollTop;

      filterElem = this.template.querySelector(".filter-panel");
      filterElemHeight = filterElem.clientHeight;
      filterElemOffsetTop = filterElem.offsetTop;

      popoverElem = this.template.querySelector(".vsm-popover");
      popoverHeight = popoverElem.clientHeight;

      if (filterContainerElemScrollTop > 0) {
        popoverTopCalculation =
          filterElemOffsetTop +
          filterElemHeight / 2 -
          popoverHeight / 2 -
          filterContainerElemScrollTop;
      } else {
        popoverTopCalculation =
          filterElemOffsetTop + filterElemHeight / 2 - popoverHeight / 2;
      }

      popoverElem.style.top = `${popoverTopCalculation}px`;

      const eventData = {
        elem: this.template,
        newTopCalculation:
          filterElemOffsetTop + filterElemHeight / 2 - popoverHeight / 2
      };

      this._scrollEventCallback = this.scrollEventCallback.bind(
        null,
        eventData
      );
      filterContainerElem.addEventListener("scroll", this._scrollEventCallback);
    }, 0);
  }

  handleOwnerClose() {
    this.showOwnerFilter = false;
  }

  handleOwnerDone() {
    this.ownerValue = this.ownerSelected;
    this.showOwnerFilter = false;
    this.showCancelAndSave = true;
  }

  handleChangeOwner(event) {
    this.ownerSelected = event.detail.value;
  }

  getUniqueKey(key) {
    return `${key}_` + Math.random().toString(36).substr(2, 9);
  }

  handleChangeField(event) {
    this.fieldSelected = event.detail.value;
    this.fieldLabelSelected = event.target.options.find(
      (opt) => opt.value === event.detail.value
    ).label;

    if (this.fieldTypeMap.get(event.detail.value) === "BOOLEAN") {
      this.isText = false;
      this.isPicklist = false;
      this.isCheckbox = true;
    } else if (this.fieldTypeMap.get(event.detail.value) === "PICKLIST") {
      this.isPicklist = true;
      this.isText = false;
      this.isCheckbox = false;
      this.picklistValue = this.fieldAndItsPicklistValues.get(
        event.detail.value
      );

      for (let element of this.picklistValue) {
        const obj = {
          label: element,
          value: element
        };

        this.picklistOption.push(obj);
      }
    } else {
      this.isText = true;
      this.isPicklist = false;
      this.isCheckbox = false;
    }
  }

  handleChangeOperator(event) {
    this.operatorSelected = event.detail.value;
    this.operatorLabelSelected = event.target.options.find(
      (opt) => opt.value === event.detail.value
    ).label;
  }

  handleChangeValue(event) {
    this.valueSelected = event.detail.value;
  }

  closeAllPopovers() {
    this._showPopover = false;
    this.showOwnerFilter = false;

    this.filterList = this.filterList.map((item) => {
      const filter = Object.assign({}, item);
      filter["showPopover"] = false;
      return filter;
    });
  }

  resetFields() {
    this.fieldSelected = "Acceptance_Criteria__c";
    this.fieldLabelSelected = "Acceptance Criteria";
    this.operatorLabelSelected = "Equal";
    this.operatorSelected = "=";
    this.valueSelected = "";

    this.isText = true;
    this.isPicklist = false;
    this.isCheckbox = false;
  }

  handleClose(event) {
    const filterId = event.target.dataset.filterid;
    let filterIndex;

    if (filterId === "emptyFilter") {
      filterIndex = this.filterList.findIndex(
        (filter) => filter.id === "emptyFilter"
      );

      if (filterIndex > -1) {
        this.filterList.splice(filterIndex, 1);
      }
    } else {
      filterIndex = this.filterList.findIndex(
        (filter) => filter.id === filterId
      );
      this.filterList[filterIndex].showPopover = false;
    }

    this._showPopover = false;
    this.resetFields();
  }

  handleDone(event) {
    const filterId = event.target.dataset.filterid;
    this.showCancelAndSave = true;

    let filterIndex;
    let newFilterId = "";
    let filterObject = {
      id: "",
      fieldSelected: this.fieldSelected,
      operatorUsed: this.operatorSelected,
      valueForField: this.valueSelected,
      fieldLabelSelected: this.fieldLabelSelected,
      operatorLabelSelected: this.operatorLabelSelected,
      fieldTypeSelected: this.fieldTypeMap.get(this.fieldSelected),
      showPopover: false,
      isEmpty: false
    };

    if (filterId === "emptyFilter") {
      filterIndex = this.filterList.findIndex(
        (filter) => filter.id === "emptyFilter"
      );
      newFilterId = this.getUniqueKey("filter");

      filterObject.id = newFilterId;

      this.filterList.push(filterObject);

      if (filterIndex > -1) {
        this.filterList.splice(filterIndex, 1);
      }
    } else {
      filterIndex = this.filterList.findIndex(
        (filter) => filter.id === filterId
      );

      filterObject.id = filterId;

      this.filterList[filterIndex] = filterObject;
    }

    this.resetFields();
    this.filterList[filterIndex].showPopover = false;
  }

  async saveFilter() {
    this.showCancelAndSave = !this.showCancelAndSave;
    const configuration = {
      filterString: JSON.stringify(this.filterList),
      ownerString: this.ownerSelected,
      recordId: this.recordId,
      selectFieldSet: this.fieldset,
      recordLimit: this.recordLimit
    };
    const safeFilterUserStory = handleAsyncError(this._filter, {
      title: ERROR
    });
    let result = await safeFilterUserStory(this, {
      config: JSON.stringify(configuration)
    });
    if (result) {
      result = new DataProcessor(result).execute();
    }
    if (
      (!this.filterList || !this.filterList.length) &&
      this.ownerSelected === "All User Stories"
    ) {
      this.dispatchEvent(
        new CustomEvent(DEFAULT_FILTER_EVENT, {
          detail: this._getSearchObj(result)
        })
      );
    } else {
      this.dispatchEvent(
        new CustomEvent(SEARCH_EVENT, { detail: this._getSearchObj(result) })
      );
    }
  }
  _filter(self, config) {
    return filterUSerStory(config);
  }

  setPopoverPosition(mode, filterId) {
    let filterContainerElem, filterContainerElemScrollTop;
    let filterElem, filterElemHeight, filterElemOffsetTop;
    let popoverElem, popoverHeight;
    let popoverTopCalculation;

    filterContainerElem = this.template.querySelector(".filter-container");
    filterContainerElemScrollTop = filterContainerElem.scrollTop;

    if (mode === this.modes.NEW) {
      filterElem = this.template.querySelector(".filter-info-wrapper-empty")
        .parentElement;
    } else if (mode === this.modes.EDIT) {
      filterElem = this.template.querySelector('*[id^="' + filterId + '"]')
        .parentElement;
    }

    filterElemHeight = filterElem.clientHeight;
    filterElemOffsetTop = filterElem.offsetTop;

    popoverElem = this.template.querySelector(".vsm-popover");
    popoverHeight = popoverElem.clientHeight;

    if (filterContainerElemScrollTop > 0) {
      popoverTopCalculation =
        filterElemOffsetTop +
        filterElemHeight / 2 -
        popoverHeight / 2 -
        filterContainerElemScrollTop;
    } else {
      popoverTopCalculation =
        filterElemOffsetTop + filterElemHeight / 2 - popoverHeight / 2;
    }

    popoverElem.style.top = `${popoverTopCalculation}px`;

    const eventData = {
      elem: this.template,
      newTopCalculation:
        filterElemOffsetTop + filterElemHeight / 2 - popoverHeight / 2
    };

    this._scrollEventCallback = this.scrollEventCallback.bind(null, eventData);
    filterContainerElem.addEventListener("scroll", this._scrollEventCallback);
  }

  togglePopover(event) {
    let mode = "";
    let filterIndex;
    let filterId = "";

    this.closeAllPopovers();
    this._showPopover = true;

    if (event) {
      filterId = event.currentTarget.dataset.filterid;
      filterIndex = this.filterList.findIndex(
        (filter) => filter.id === filterId
      );
      mode = this.modes.EDIT;
    } else {
      filterIndex = this.filterList.findIndex(
        (filter) => filter.id === "emptyFilter"
      );
      mode = this.modes.NEW;
    }

    this.filterList[filterIndex].showPopover = true;

    if (mode === this.modes.NEW) {
      setTimeout(() => {
        this.setPopoverPosition(mode, null);
      }, 0);
    } else if (mode === this.modes.EDIT) {
      setTimeout(() => {
        this.setPopoverPosition(mode, filterId);

        // Recover filter data in popover
        this.fieldSelected = this.filterList[filterIndex].fieldSelected;
        this.fieldLabelSelected = this.filterList[
          filterIndex
        ].fieldLabelSelected;
        this.operatorLabelSelected = this.filterList[
          filterIndex
        ].operatorLabelSelected;
        this.operatorSelected = this.filterList[filterIndex].operatorUsed;
        this.valueSelected = this.filterList[filterIndex].valueForField;

        if (this.fieldTypeMap.get(this.fieldSelected) === "PICKLIST") {
          this.isPicklist = true;
          this.isText = false;
          this.isCheckbox = false;
          this.picklistValue = this.fieldAndItsPicklistValues.get(
            this.fieldSelected
          );

          for (let element of this.picklistValue) {
            const obj = {
              label: element,
              value: element
            };

            if (this.valueSelected != element) {
              this.picklistOption.push(obj);
            }
          }
        }
      }, 0);
    }
  }

  addFilter() {
    const emptyFilterIndex = this.filterList.findIndex(
      (filter) => filter.id === "emptyFilter"
    );

    const filterObject = {
      id: "emptyFilter",
      fieldSelected: "",
      operatorUsed: "",
      valueForField: "",
      fieldLabelSelected: "",
      operatorLabelSelected: "",
      fieldTypeSelected: this.fieldTypeMap.get(this.fieldSelected),
      showPopover: false,
      isEmpty: true
    };

    this.resetFields();

    if (emptyFilterIndex === -1) {
      this.filterList.push(filterObject);
      this.togglePopover(null);
    }
  }

  removeFilter(event) {
    event.stopPropagation();
    const filterId = event.target.dataset.filterid;
    const filterIndex = this.filterList.findIndex(
      (filter) => filter.id === filterId
    );

    if (filterIndex > -1) {
      this.filterList.splice(filterIndex, 1);
      this._showPopover = false;
      this.showCancelAndSave=true;
    }
  }

  removeAllFilters() {
    this.filterList = [];
    this._showPopover = false;
    this.showCancelAndSave = true;
  }
  sortArray(list) {
    return list.sort((a, b) => (a.label > b.label ? 1 : -1));
  }

  getData() {
    getFieldForUserStory()
      .then((result) => {
        this.fieldList = result;

        for (let i = 0; i < this.fieldList.length; i++) {
          this.fieldRelatedToUserStory.push({
            label: this.fieldList[i].fieldName,
            value: this.fieldList[i].fieldApi
          });
          this.fieldTypeMap.set(
            this.fieldList[i].fieldApi,
            this.fieldList[i].type
          );

          if (this.fieldList[i].type === "PICKLIST") {
            this.fieldAndItsPicklistValues.set(
              this.fieldList[i].fieldApi,
              this.fieldList[i].options
            );
          }
        }
        this.fieldRelatedToUserStory = this.sortArray(
          this.fieldRelatedToUserStory
        );
        this.error = undefined;
      })
      .catch((error) => {
        this.error = error;
        this.fieldList = undefined;
      });
  }

  connectedCallback() {
    this.getData();
  }
  _clearSearch() {
    this.data = [];
    this.searchValue = "";
    this.searchDataCount = 0;
    this.dispatchEvent(new CustomEvent(CLEAR_SEARCH_EVENT));
  }
  _getSearchObj(data) {
    data = data ? data : [];
    return {
      searchedData: data,
      searchDataCount: data.length,
      searchTerm: undefined
    };
  }
}