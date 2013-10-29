angular.module('agentscriptUi', [])
	.directive('asUi', [function() {
		return {
			template:
				"<div ng-repeat='(name, el) in asUi'>" +
					"<div ng-switch on='el.type'>" +
						"<div ng-switch-when='button' as-button='el' fb-ui='fbUi' as-name='{{name}}'>" +
						"</div>" +
						"<div ng-switch-when='choice' class='as-choice'>" +
							"choice: {{ name }}" +
						"</div>" +
						"<div ng-switch-when='switch' class='as-switch'>" +
							"switch: {{ name }}" +
						"</div>" +
						"<div ng-switch-when='slider' class='as-slider'>" +
							"slider: {{ name }}" +
						"</div>" +
					"</div>" +
				"</div>",
			scope: {
				asUi: "=",
				fbUi: "="
			},
			link: function($scope, $el, $attrs) {
				// console.log($scope);
			}
		};
	}])
	.directive('asButton', [function() {
		return {
			template:
				"<div class='as-button' ng-class='{ toggled: asButton.val }'>" +
					"{{ asName }}" +
				"</div>",
			scope: {
				asButton: "=",
				asName: "@",
				fbUi: "="
			},
			replace: true,
			link: function($scope, $el, $attrs) {
				// console.log("child scope", $scope);
				$el.bind("click", function() {
					var currentVal = $scope.asButton.val;
					if (!currentVal) {
						$scope.fbUi.setUIValue($scope.asName, true);
					}
				});
			}
		};
	}]);