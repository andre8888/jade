# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
pin "lodash", to: "https://ga.jspm.io/npm:lodash@4.17.21/lodash.js"
pin "loanjs", to: "https://ga.jspm.io/npm:loanjs@1.1.2/LoanJS.js"
pin "@googlemaps/js-api-loader", to: "https://ga.jspm.io/npm:@googlemaps/js-api-loader@1.16.2/dist/index.esm.js"
pin "@rails/request.js", to: "https://ga.jspm.io/npm:@rails/request.js@0.0.9/src/index.js"
pin "pluralize", to: "https://ga.jspm.io/npm:pluralize@8.0.0/pluralize.js"
pin "alpinejs", to: "https://ga.jspm.io/npm:alpinejs@3.14.1/dist/module.esm.js"
pin "@fortawesome/fontawesome-free", to: "https://ga.jspm.io/npm:@fortawesome/fontawesome-free@6.5.2/js/fontawesome.js"
pin "@fortawesome/fontawesome-svg-core", to: "https://ga.jspm.io/npm:@fortawesome/fontawesome-svg-core@6.5.2/index.mjs"
pin "@fortawesome/free-brands-svg-icons", to: "https://ga.jspm.io/npm:@fortawesome/free-brands-svg-icons@6.5.2/index.mjs"
pin "@fortawesome/free-regular-svg-icons", to: "https://ga.jspm.io/npm:@fortawesome/free-regular-svg-icons@6.5.2/index.mjs"
pin "@fortawesome/free-solid-svg-icons", to: "https://ga.jspm.io/npm:@fortawesome/free-solid-svg-icons@6.5.2/index.mjs"
pin "datatables.net-dt", to: "https://ga.jspm.io/npm:datatables.net-dt@2.0.8/js/dataTables.dataTables.mjs"
pin "datatables.net", to: "https://ga.jspm.io/npm:datatables.net@2.0.8/js/dataTables.mjs"
pin "jquery", to: "https://ga.jspm.io/npm:jquery@3.7.1/dist/jquery.js"
