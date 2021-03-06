#!/bin/bash
ORDER=$(cat <<EOF
{
  "metadata": {
    "retailer": {
      "href": "http://www.operator.com/entities/retailer.com"
    },
    "retail-customer": "47890",
    "retailer-order-reference": "1234567",
    "creation-date": "${NOW}"
  },
  "gaming-product-orders": {
    "http://www.operator.com/gaming-products/foo": {
    	"bets": [
      	{
          "cats": [1, 2, 3, 4, 5],
          "dogs": [1, 8]
        },
        {
          "cats": [2, 4, 6, 29, 32],
          "dogs": [4, 5]
        },
        {
          "cats": [6, 9, 11, 34, 56],
          "dogs": [3, 4]
        }
      ],
      "participation-pools": {
        "first-draw": "${IN_TWO_DAYS}",
        "draw-count": 8
      }
   },
   "http://www.operator.com/gaming-products/bar": {
     "bets": [
       {
         "drinks": [1, 4, 6, 88]
       }
     ],
     "participation-pools": {
       "cycles": ["AM", "PM"],
       "first-draw": "${IN_THREE_DAYS}",
       "draw-count": 20
     }
   }
  }

}
EOF
)
