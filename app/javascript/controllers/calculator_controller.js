import { Controller } from '@hotwired/stimulus'
import { Loan } from 'loanjs'
import { Loader } from '@googlemaps/js-api-loader'
import { get, post, put, patch, destroy } from '@rails/request.js'
import pluralize from 'pluralize'

export default class extends Controller {
    static targets = [
        'form',
        'places_api_key',
        'market_strategy',
        'str',
        'ltr',
        'sale_price',
        'down_payment',
        'loan_amount',
        'interest_rate',
        'loan_length',
        'monthly_mortgage',
        'closing_cost',
        'rehab_cost',
        'furniture_cost',
        'initial_cash_investment',
        'avg_daily_rate',
        'occupancy_rate',
        'est_monthly_rent',
        'est_monthly_rent_ltr',
        'maintenance',
        'property_tax',
        'property_tax_rate',
        'annual_insurance',
        'property_management_fees',
        'monthly_hoa',
        'booking_lodging_fees',
        'monthly_supplies',
        'monthly_utilities',
        'monthly_expenses',
        'monthly_cash_flow',
        'coc_return',
        'year_1_debt_paydown',
        'appreciation',
        'annualized_roi',
        'street1',
        'bedroom',
        'bathroom',
        'living_area',
        'year_built',
        'market_value',
        'property_link',
        'rent_median',
        'rent_min',
        'rent_max',
        'projected_revenue'
    ]

    initialize() {
        this.MARKET_TYPE = Object.freeze({
            short_term: 'str',
            long_term: 'ltr'
        });
        this.market_type = ''
        this._autocomplete = null
        this.initCalculator()
    }

    connect() {
        this.handleMarketType()
        this.initGoogleAutoComplete()
    }

    initCalculator() {
        this.sale_price = 0
        this.down_payment_percentage = 0
        this.down_payment = 0
        this.loan_amount = 0
        this.interest_rate_percentage = 0
        this.loan_length = 0
        this.monthly_mortgage = 0
        this.year_built = 0
        this.loan = {}

        this.closing_cost = 0
        this.rehab_cost = 0
        this.furniture_cost = 0
        this.initial_cash_investment = 0

        this.avg_daily_rate = 0
        this.occupancy_rate = 0

        this.monthly_rent = 0
        this.monthly_rent_ltr = 0
        this.monthly_maintenance = 0
        this.monthly_property_tax = 0
        this.monthly_insurance = 0
        this.monthly_property_management = 0
        this.monthly_hoa = 0
        this.monthly_booking = 0
        this.monthly_supplies = 0
        this.monthly_utilities = 0
        this.monthly_expenses = 0

        this.monthly_cash_flow = 0
        this.cash_on_cash_return = 0
        this.year_1_debt_paydown_percentage = 0
        this.appreciation_percentage = 0
        this.annualized_roi_percentage = 0
    }

    initGoogleAutoComplete() {
        const loader = new Loader({
            apiKey: this.places_api_keyTarget.value,
            version: 'weekly',
            libraries: ['core', 'maps', 'places', 'geometry', 'geocoding']
        });

        loader
            .load()
            .then(async (google) => {
                const { Autocomplete } = await google.maps.importLibrary('places')
                const autocomplete_options = {
                    componentRestrictions: { country: 'us' },
                    fields: ['address_components', 'formatted_address', 'geometry'],
                    strictBounds: false,
                };
                this._autocomplete = new Autocomplete(this.street1Target, autocomplete_options)
                const { event } = await google.maps.importLibrary('core')
                event.addListener(this._autocomplete, 'place_changed', this.locationChanged.bind(this));
            })
            .catch(e => {
                console.log(e)
            });
    }

    locationChanged() {
        const place = this._autocomplete.getPlace()
        if (place === undefined) return

        this.toggleResults(true)
        if (!place.geometry) {
            // TODO: handle error
            console.log('Invalid location')
            return
        }
        // console.log('You selected: ' + place.formatted_address)
        this.fetchPropertyData()
    }

    async fetchPropertyData() {
        this.initCalculator()
        this.formTarget.querySelector('.property-details').classList.add('hidden')
        this.formTarget.querySelector('.rent-details').classList.add('hidden')
        this.formTarget.querySelector('.adr-details').classList.add('hidden')
        this.formTarget.querySelector('.skeleton').classList.remove('hidden')

        const response = await post(
            '/calculator/run',
            { body: new FormData(this.formTarget), responseKind: 'json' }
        )
        if (response.ok) {
            this.toggleResults(false)
            const body = await response.json
            // console.log(body)

            if (body.data.sale_price) {
                this.sale_priceTarget.value = body.data.sale_price
            }
            if (body.data.rent_estimate) {
                this.est_monthly_rent_ltrTarget.value = body.data.rent_estimate
            }
            if (body.data.average_daily_rate) {
                this.avg_daily_rateTarget.value = body.data.average_daily_rate
            }
            if (body.data.occupancy_rate) {
                this.occupancy_rateTarget.value = body.data.occupancy_rate
            }

            this.showPropertyDetails(body)
            this.showRentalDetails(body)
            this.showDailyRateDetails(body)
            if (this.market_type === this.MARKET_TYPE.long_term) {
                this.formTarget.querySelector('.rent-details').classList.remove('hidden')
                this.formTarget.querySelector('.adr-details').classList.add('hidden')
            } else if (this.market_type === this.MARKET_TYPE.short_term) {
                this.formTarget.querySelector('.adr-details').classList.remove('hidden')
                this.formTarget.querySelector('.rent-details').classList.add('hidden')
            }

            this.property_tax_rateTarget.value = body.data.property_tax_rate
            // if (body.data.property_tax) {
            //     this.property_taxTarget.value = body.data.property_tax
            // }
            this.monthly_hoaTarget.value = body.data.hoa
            if (body.data.insurance) {
                this.annual_insuranceTarget.value = body.data.insurance / 2 // estimate is too high!
            }
            if (body.data.year_built) {
                this.year_built = body.data.year_built
                this.handleMaintenance()
            }

            this.handleLoanAmount()
            this.handleMonthlyRent()
        } else {
            this.toggleResults(true)
        }
    }

    showDailyRateDetails(body) {
        if (body.data.projected_revenue) {
            this.projected_revenueTarget.innerHTML = 'Projected Revenue: $' + body.data.projected_revenue
        }
    }

    showRentalDetails(body) {
        if (body.data.rent_median) {
            this.rent_medianTarget.innerHTML = 'Median: $' + body.data.rent_median
        }
        if (body.data.rent_min) {
            this.rent_minTarget.innerHTML = 'Min: $' + body.data.rent_min
        }
        if (body.data.rent_max) {
            this.rent_maxTarget.innerHTML = 'Max: $' + body.data.rent_max
        }
    }

    showPropertyDetails(body) {
        if (body.data.bedrooms) {
            this.bedroomTarget.innerHTML = pluralize('bedroom', body.data.bedrooms, true)
        }
        if (body.data.bathrooms) {
            this.bathroomTarget.innerHTML = pluralize('bathroom', body.data.bathrooms, true)
        }
        if (body.data.living_area) {
            this.living_areaTarget.innerHTML = pluralize('sq foot', body.data.living_area, true)
        }
        if (body.data.year_built) {
            this.year_builtTarget.innerHTML = 'Year Built: ' + body.data.year_built
        }
        if (body.data.property_link) {
            this.property_linkTarget.href = body.data.property_link
        }
        if (body.data.market_value) {
            this.market_valueTarget.innerHTML = 'Market Value: $' + body.data.market_value
        }
        this.formTarget.querySelector('.property-details').classList.remove('hidden')
    }

    toggleResults(hide = true) {
        if (hide) {
            this.formTarget.querySelector('.skeleton').classList.remove('hidden')
            this.formTarget.querySelectorAll('.calc-section, .metrics').forEach(e => e.classList.add('hidden'));
        } else { // show results
            this.formTarget.querySelector('.skeleton').classList.add('hidden')
            this.formTarget.querySelectorAll('.calc-section, .metrics').forEach(e => e.classList.remove('hidden'));
        }
    }

    handleLoanAmount() {
        this.sale_price = parseInt(this.sale_priceTarget.value || 0)
        this.down_payment_percentage = parseInt(this.down_paymentTarget.value || 0)
        this.down_payment = parseInt(this.sale_price * (this.down_payment_percentage / 100))
        this.loan_amount = this.sale_price - this.down_payment
        this.loan_amountTarget.value = this.loan_amount
        this.handleMonthlyMortgage()
    }

    handleMonthlyMortgage() {
        this.interest_rate_percentage = this.interest_rateTarget.value || 0
        this.loan_length = this.loan_lengthTarget.value || 0
        if (this.loan_amount > 0 && this.loan_length > 0) {
            this.loan = new Loan(this.loan_amount, this.loan_length * 12, this.interest_rate_percentage, 'annuity')
            if (this.loan && this.loan.installments) { // https://github.com/kfiku/loanjs
                this.monthly_mortgage = Math.round(this.loan.installments[0].installment)
            }
        }
        this.monthly_mortgageTarget.value = this.monthly_mortgage
        this.handleMonthlyExpenses()
        this.handleInitialCashInvestment()
    }

    handleInitialCashInvestment() {
        this.closing_cost_percentage = this.closing_costTarget.value || 0
        this.closing_cost = this.loan_amount * (this.closing_cost_percentage / 100)
        this.rehab_cost = this.rehab_costTarget.value || 0
        this.furniture_cost = this.furniture_costTarget.value || 0
        if (this.market_type === this.MARKET_TYPE.long_term) this.furniture_cost = 0
        const costs = parseInt(this.closing_cost) + parseInt(this.rehab_cost) + parseInt(this.furniture_cost)
        this.initial_cash_investment = this.down_payment + costs
        this.initial_cash_investmentTarget.value = this.initial_cash_investment
        this.handleMetrics()
    }

    handleMaintenance() {
        this.maintenanceTarget.value = 5 // default for str
        if (this.market_type === this.MARKET_TYPE.long_term) {
            this.maintenanceTarget.value = this.year_built < 2018 ? 15 : 10
        }
    }

    handleLodging() {
        this.booking_lodging_feesTarget.value = 3 // default for str
        if (this.market_type === this.MARKET_TYPE.long_term) {
            this.booking_lodging_feesTarget.value = 0
        }
    }

    handleMonthlySuppliesAndUtilities() {
        // default for str
        this.monthly_suppliesTarget.value = 200
        this.monthly_utilitiesTarget.value = 250
        if (this.market_type === this.MARKET_TYPE.long_term) {
            // default for ltr
            this.monthly_suppliesTarget.value = 0
            this.monthly_utilitiesTarget.value = 0
        }
    }

    handleMonthlyRent() {
        if (this.market_type === this.MARKET_TYPE.long_term) {
            this.avg_daily_rate = 0
            this.occupancy_rate = 0
            this.monthly_rent_ltr = this.est_monthly_rent_ltrTarget.value
        } else if (this.market_type === this.MARKET_TYPE.short_term) {
            this.avg_daily_rate = this.avg_daily_rateTarget.value || 0
            this.occupancy_rate = this.occupancy_rateTarget.value || 0
            this.monthly_rent = Math.round(((this.avg_daily_rate * 365) * (this.occupancy_rate / 100)) / 12)
            this.est_monthly_rentTarget.value = this.monthly_rent
        }
        this.handleMonthlyExpenses()
    }

    handleMonthlyExpenses() {
        const rent = this.market_type === this.MARKET_TYPE.long_term ? this.monthly_rent_ltr : this.monthly_rent
        this.monthly_maintenance = ((this.maintenanceTarget.value || 0) / 100) * rent
        this.monthly_property_management = ((this.property_management_feesTarget.value || 0) / 100) * rent
        this.monthly_property_tax = ((parseFloat(this.property_tax_rateTarget.value || 0) / 100) * this.sale_price) / 12
        this.property_taxTarget.value = this.monthly_property_tax
        this.monthly_insurance = parseInt(this.annual_insuranceTarget.value || 0)
        this.monthly_hoa = parseInt(this.monthly_hoaTarget.value || 0)
        this.monthly_booking = ((this.booking_lodging_feesTarget.value || 0) / 100) * rent
        this.monthly_supplies = this.market_type === this.MARKET_TYPE.long_term ? 0 : parseInt(this.monthly_suppliesTarget.value || 0)
        this.monthly_utilities = parseInt(this.monthly_utilitiesTarget.value || 0)
        this.monthly_expenses = this.monthly_mortgage +
            this.monthly_maintenance +
            this.monthly_property_tax +
            this.monthly_insurance +
            this.monthly_property_management +
            this.monthly_hoa +
            this.monthly_booking +
            this.monthly_supplies +
            this.monthly_utilities
        this.monthly_expensesTarget.value = Math.round(this.monthly_expenses)
        this.handleMetrics()
    }

    handleMetrics() {
        const rent = this.market_type === this.MARKET_TYPE.long_term ? this.monthly_rent_ltr : this.monthly_rent
        this.monthly_cash_flow = rent - this.monthly_expenses
        this.monthly_cash_flowTarget.value = Math.round(this.monthly_cash_flow)

        this.cash_on_cash_return = ((this.monthly_cash_flow * 12) / this.initial_cash_investment) * 100
        if (isNaN(this.cash_on_cash_return)) return
        this.coc_returnTarget.value = this.cash_on_cash_return.toFixed(2)

        let year_1_balance = 0
        if (this.loan && this.loan.installments) {
            year_1_balance = Math.round(this.loan.installments[11].remain)
        }
        this.year_1_debt_paydown_percentage = ((this.loan_amount - year_1_balance) / this.initial_cash_investment) * 100
        this.year_1_debt_paydownTarget.value = this.year_1_debt_paydown_percentage.toFixed(2)

        this.appreciation_percentage = (0.03 * (100 / this.down_payment)) * 100
        this.appreciationTarget.value = this.appreciation_percentage.toFixed(2)

        this.annualized_roi_percentage =
            this.cash_on_cash_return +
            this.year_1_debt_paydown_percentage +
            this.appreciation_percentage
        this.annualized_roiTarget.value = this.annualized_roi_percentage.toFixed(2)
    }

    handleMarketType() {
        this.market_type = this.market_strategyTargets.find(radio => radio.checked).value
        if (this.market_type === this.MARKET_TYPE.long_term) {
            this.initLTR();
        } else if (this.market_type === this.MARKET_TYPE.short_term) {
            this.initSTR();
        }
        this.handleMaintenance()
        this.handleLodging()
        this.handleMonthlySuppliesAndUtilities()
        this.handleInitialCashInvestment()
        this.handleMonthlyRent()
    }

    initSTR() {
        this.est_monthly_rentTarget.classList.remove('hidden')
        this.est_monthly_rent_ltrTarget.classList.add('hidden')
        this.strTargets.forEach(el => {
            el.hidden = false
        });
        this.ltrTargets.forEach(el => {
            el.hidden = true
        });
        this.property_management_feesTarget.value = 0
        this.formTarget.querySelector('.adr-details').classList.remove('hidden')
        this.formTarget.querySelector('.rent-details').classList.add('hidden')
    }

    initLTR() {
        this.est_monthly_rentTarget.classList.add('hidden')
        this.est_monthly_rent_ltrTarget.classList.remove('hidden')
        this.ltrTargets.forEach(el => {
            el.hidden = false
        });
        this.strTargets.forEach(el => {
            el.hidden = true
        });
        this.property_management_feesTarget.value = 6
        this.formTarget.querySelector('.adr-details').classList.add('hidden')
        this.formTarget.querySelector('.rent-details').classList.remove('hidden')
    }
}
