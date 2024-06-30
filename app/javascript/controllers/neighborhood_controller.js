import {Controller} from '@hotwired/stimulus'
import {Loader} from '@googlemaps/js-api-loader'
// import DataTable from 'datatables.net-dt';

export default class extends Controller {
    static targets = [
        'form',
        'places_api_key',
        'location'
    ]

    initialize() {
        this._autocomplete = null
    }

    connect() {
        this.initGoogleAutoComplete()
        // document.addEventListener('turbo:before-frame-render', () => {
        //     console.log('before frame stream rendered');
        // });
        // document.addEventListener('turbo:before-stream-render', () => {
        //     console.log('before turbo stream rendered');
        // });
        // document.addEventListener('turbo:stream-render', () => {
        //     console.log('turbo stream rendered');
        // });
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
                const {Autocomplete} = await google.maps.importLibrary('places')
                const autocomplete_options = {
                    componentRestrictions: {country: 'us'},
                    fields: ['address_components', 'formatted_address', 'geometry'],
                    strictBounds: false,
                };
                this._autocomplete = new Autocomplete(this.locationTarget, autocomplete_options)
                const {event} = await google.maps.importLibrary('core')
                event.addListener(this._autocomplete, 'place_changed', this.locationChanged.bind(this));
            })
            .catch(e => {
                console.log(e)
            });
    }

    locationChanged() {
        const place = this._autocomplete.getPlace()
        if (place === undefined) return
        if (!place.geometry) {
            // TODO: handle error
            console.log('Invalid location')
        }
        console.log('You selected: ' + place.formatted_address)
    }
}
