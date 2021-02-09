(() => {
  // NOTE: only for linter and clarity:
  /* global _ */
  /* global _jed */
  const React = window.React
  const ReactDOM = window.ReactDOM
  const Autocomplete = window.ReactAutocomplete
  React.findDOMNode = ReactDOM.findDOMNode // NOTE: autocomplete lib needs this

  window.InputInventoryCode = window.createReactClass({
    propTypes: {
    },

    getInitialState() {
      return {
        selected: 'plusOne'
      }
    },

    _plusOne() {
      event.preventDefault()
      this.setState({selected: 'plusOne'})
      var l = window.lodash
      var value = l.cloneDeep(this.props.selectedValue.value)
      value.text = this.props.inventoryCodeProps.next_code
      this.props.onChange(value)
    },

    _fillGap() {
      event.preventDefault()
      this.setState({selected: 'fillGap'})
      var l = window.lodash
      var value = l.cloneDeep(this.props.selectedValue.value)
      value.text = this.props.inventoryCodeProps.lowest_code
      this.props.onChange(value)
    },

    _maximum() {
      event.preventDefault()
      this.setState({selected: 'maximum'})
      var l = window.lodash
      var value = l.cloneDeep(this.props.selectedValue.value)
      value.text = this.props.inventoryCodeProps.highest_code
      this.props.onChange(value)
    },

    _renderPlusOne() {
      return (null
      )
    },

    _renderFillGap() {
      return (null
      )
    },

    _renderMaximum() {
      return (null
      )
    },

    _renderButtons() {
      if(this.props.editMode) {
        return null
      }

      return (
        <div className='row text-align-right' id='switch'>
          <button type='button' onClick={this._plusOne} className={'button small ' + (this.state.selected == 'plusOne' ? 'green' : 'white')}>
            {' ' + _jed('last used +1') + ' '}
          </button>
          {' '}
          <button type='button' onClick={this._fillGap} className={'button small ' + (this.state.selected == 'fillGap' ? 'green' : 'white')}>
            {' ' + _jed('fill up gaps') + ' '}
          </button>
          {' '}
          <button type='button' onClick={this._maximum} className={'button small ' + (this.state.selected == 'maximum' ? 'green' : 'white')}>
            {' ' + _jed('assign highest available') + ' '}
          </button>
        </div>
      )

    },

    render () {

      const props = this.props
      const selectedValue = props.selectedValue

      var fieldClass = 'field row emboss padding-inset-xs margin-vertical-xxs margin-right-xs'
      if(this.props.error) {
        fieldClass += ' error'
      }
      if(selectedValue.hidden) {
        fieldClass += ' hidden'
      }

      return (
        <div className={fieldClass} data-editable='true' data-id='inventory_code' data-required='true' data-type='field'>
          <div className='row'>
            {RenderFieldLabel._renderFieldLabel(selectedValue.field, this.props.onClose, true)}
            <InputText selectedValue={selectedValue} onChange={this.props.onChange} />
          </div>
          {this._renderButtons()}
        </div>
      )
    }
  })
})()
