import React from 'react'
import VisitRow from './visits_index/VisitRow'
import cx from 'classnames'
import f from 'lodash'
const DatePickerWithInput = window.DatePickerWithInput
const Scrolling = window.Scrolling
const i18n = window.i18n

class VisitsIndex extends React.Component {
  constructor() {
    super()

    this.resetConfig = {
      offset: 0,
      visits: [],
      isLoadedAll: false,
      loadingFirstPage: true
    }

    this.state = f.merge(
      {
        search_term: null,
        tab: 'all',
        startDate: '',
        endDate: '',
        verification: 'irrelevant'
      },
      this.resetConfig
    )

    this.searchTermCallback = this.searchTermCallback.bind(this)
    this.debouncedFetch = f.debounce(this.fetch, 300)
    this.currentXHRRequest = null
  }

  componentDidMount() {
    Scrolling.mount(this.onScroll.bind(this))
    this.fetch()
  }

  componentWillUnmount() {
    Scrolling.unmount(this.onScroll.bind(this))
  }

  onScroll() {
    this.tryLoadNext()
  }

  tryLoadNext() {
    if (!this.state.loadingAdditionalPage && !this.state.isLoadedAll && Scrolling._isBottom()) {
      this.loadNext()
    }
  }

  loadNext() {
    this.setState(
      {
        loadingAdditionalPage: true
      },
      this.fetch
    )
  }

  searchTermCallback(event) {
    const value = event.target.value
    this.setState(
      f.merge(
        {
          search_term: value
        },
        this.resetConfig
      ),
      this.debouncedFetch
    )
  }

  formatDateForFetch(dateString) {
    return f.isEmpty(dateString) ? dateString : moment(dateString, i18n.date.L).format('YYYY-MM-DD')
  }

  getVisitTypesForTab() {
    let type
    switch (this.state.tab) {
      case 'all':
        type = ['hand_over', 'take_back']
        break
      case 'hand_over':
        type = ['hand_over']
        break
      case 'take_back':
        type = ['take_back']
        break
    }
    return type
  }

  fetch() {
    if (this.currentXHRRequest) {
      this.currentXHRRequest.abort()
      this.currentXHRRequest = null
    }

    this.currentXHRRequest = $.ajax({
      url: `/manage/${this.props.inventory_pool_id}/visits`,
      method: 'GET',
      dataType: 'json',
      data: $.param({
        type: this.getVisitTypesForTab(),
        search_term: this.state.search_term,
        range: {
          start_date: this.formatDateForFetch(this.state.startDate),
          end_date: this.formatDateForFetch(this.state.endDate)
        },
        offset: this.state.offset,
        limit: 20,
        paginate: false,
        verification: this.state.verification
      }),
      success: data => {
        this.currentXHRRequest = null
        this.onFetchSuccessCallback(data)
      },
      error: () => {
        this.currentXHRRequest = null
      }
    })
  }

  onFetchSuccessCallback(data) {
    const setStateCallback = data.length == 0 ? null : this.tryLoadNext

    this.setState(prevState => {
      return {
        loadingFirstPage: false,
        loadingAdditionalPage: false,
        offset: prevState.offset + 20,
        visits: prevState.visits.concat(data),
        isLoadedAll: data.length == 0
      }
    }, setStateCallback)
  }

  onSelectEndDateCallback(dateString) {
    this.setState(
      f.merge(
        {
          endDate: dateString
        },
        this.resetConfig
      ),
      this.tryLoadNext
    )
  }

  onSelectStartDateCallback(dateString) {
    this.setState(
      f.merge(
        {
          startDate: dateString
        },
        this.resetConfig
      ),
      this.tryLoadNext
    )
  }

  onSelectVerificationCallback(event) {
    const value = event.target.value
    this.setState(
      f.merge(
        {
          verification: value
        },
        this.resetConfig
      ),
      this.debouncedFetch
    )
  }

  onChangeTabCallback(tab) {
    this.setState(
      f.merge(
        {
          tab: tab
        },
        this.resetConfig
      ),
      this.tryLoadNext
    )
  }

  renderStartDateInput(args) {
    return (
      <div className="col4of10">
        <label className="row">
          <input
            value={args.value}
            onChange={args.onChange}
            onFocus={args.onFocus}
            autoComplete="off"
            className="has-addon hasDatepicker"
            placeholder={_jed('from')}
            type="text"
          />
          <span className="addon" onClick={args.onFocus}>
            <i className="fa fa-calendar" />
          </span>
          {args.renderPicker()}
        </label>
      </div>
    )
  }

  renderEndDateInput(args) {
    return (
      <div className="col4of10">
        <label className="row">
          <input
            value={args.value}
            onChange={args.onChange}
            onFocus={args.onFocus}
            autoComplete="off"
            className="has-addon hasDatepicker"
            placeholder={_jed('to')}
            type="text"
          />
          <span className="addon" onClick={args.onFocus}>
            <i className="fa fa-calendar" />
          </span>
          {args.renderPicker()}
        </label>
      </div>
    )
  }

  renderPaginationLoading() {
    if (this.state.isLoadedAll) {
      return null
    } else {
      return (
        <div className="line row focus-hover-thin">
          <div className="height-s" />
          <div className="loading-bg" />
          <div className="height-s" />
        </div>
      )
    }
  }

  renderResultLoading() {
    return (
      <div>
        <div className="height-s" />
        <div className="loading-bg" />
        <div className="height-s" />
      </div>
    )
  }

  renderResultNothingFound() {
    return (
      <h3 className="headline-s light padding-inset-xl text-align-center">
        <div className="height-s" />
        {_jed('No entries found')}
        <div className="height-s" />
      </h3>
    )
  }

  renderLinesTable() {
    return (
      <div>
        {this.state.visits.map(v => <VisitRow key={v.id} v={v} />)}
        {this.renderPaginationLoading()}
      </div>
    )
  }

  renderResult() {
    if (this.state.loadingFirstPage && this.state.visits.length == 0) {
      return this.renderResultLoading()
    } else if (this.state.visits.length == 0) {
      return this.renderResultNothingFound()
    } else {
      return this.renderLinesTable()
    }
  }

  render() {
    return (
      <div className="row content-wrapper min-height-xl min-width-full straight-top">
        <div className="margin-top-l padding-horizontal-m">
          <div className="row">
            <h1 className="headline-xl">{_jed('List of Visits')}</h1>
          </div>
        </div>
        <div className="row margin-top-l">
          <div className="inline-tab-navigation" id="list-tabs">
            <a
              onClick={() => this.onChangeTabCallback('all')}
              className={cx('inline-tab-item', {
                active: this.state.tab == 'all'
              })}>
              {_jed('All')}
            </a>
            <a
              onClick={() => this.onChangeTabCallback('hand_over')}
              className={cx('inline-tab-item', {
                active: this.state.tab == 'hand_over'
              })}>
              {_jed('Hand Over')}
            </a>
            <a
              onClick={() => this.onChangeTabCallback('take_back')}
              className={cx('inline-tab-item', {
                active: this.state.tab == 'take_back'
              })}>
              {_jed('Take Back')}
            </a>
          </div>
          <div className="row margin-vertical-xs padding-horizontal-m">
            <div className="col2of6 padding-right-s">
              <input
                className="width-full"
                id="list-search"
                name="input"
                placeholder="Search..."
                type="text"
                onChange={this.searchTermCallback}
              />
            </div>
            <div className="col2of6 padding-right-s" id="list-range">
              <DatePickerWithInput
                value={this.state.startDate}
                onChange={this.onSelectStartDateCallback.bind(this)}
                customRenderer={this.renderStartDateInput}
              />
              <div className="col1of10 text-align-center">
                <div className="padding-top-s">-</div>
              </div>
              <DatePickerWithInput
                value={this.state.endDate}
                onChange={this.onSelectEndDateCallback.bind(this)}
                customRenderer={this.renderEndDateInput}
              />
            </div>
            <div className="col2of6 padding-right-xs">
              <select
                value={this.state.verification}
                onChange={this.onSelectVerificationCallback.bind(this)}
                name="verification"
                className="width-full">
                <option value="irrelevant">{_jed('All')}</option>
                <option value="no_verification">{_jed('No verification required')}</option>
                <option value="with_user_to_verify">{_jed('User to verify')}</option>
                <option value="with_user_and_model_to_verify">
                  {_jed('User and model to verify')}
                </option>
              </select>
            </div>
          </div>
          <div className="table">
            <div className="table-row">
              <div
                className="table-cell list-of-lines even separated-top padding-bottom-s min-height-l"
                id="visits">
                {this.renderResult()}
              </div>
            </div>
          </div>
        </div>
      </div>
    )
  }
}

export default VisitsIndex
