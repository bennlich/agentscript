ABM.Model.prototype.setup = function() {
    this.patches.forEach(function(p) {
        p.color = [Math.random()*255, Math.random()*255, Math.random()*255];
    });
}

ABM.Model.prototype.setVision = function() {

}

var model = new ABM.Model("layers", 1, 1, 100, 1, 100);

angular.module('myApp', ['agentscriptUi'])
	.controller('myCtrl', ['$scope', function($scope) {
		$scope.uiData = {
  			setup: {
  				type:"button",
  				setter:"setup",
  				val: false
  			},
  			background: {
  				type:"choice",
  				vals: ["black","red","random"],
  				val: "red"
  			},
			useConsole: {
				type:"switch",
				val: true
			},
  			population: {
  				type:"slider",
  				min:25,
  				step:25,
  				max:1000,
  				val:500
  			},
  			vision: {
  				type:"slider",
  				setter:"setVision",
  				min:.5,
  				step:.5,
  				max:10,
  				val:3
  			}
		};

        var fbUrl = "https://asui.firebaseio-demo.com/";
        $scope.fbUi = new ABM.FirebaseUI(fbUrl, model, $scope.uiData);

        model.start();
	}]);