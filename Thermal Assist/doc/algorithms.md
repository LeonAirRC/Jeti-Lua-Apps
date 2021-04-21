# Algorithms
## Best Subsequence
This algorithm searches for the subsequence of length 'bestSequenceLength' with the highest sum of variometer values.\
In a scenario like this, with numbers representing the climb rate at their positions,\
\
<img src="https://user-images.githubusercontent.com/57962936/115403853-14031700-a1ed-11eb-989a-be5743f78519.png" width=300>\
\
the following subsequence would be chosen:\
\
<img src="https://user-images.githubusercontent.com/57962936/115404091-490f6980-a1ed-11eb-8517-bec7fd6b43a1.png" width=400>\
\
The announcement at this moment is "56 degrees, 21 meters, 2 meters per second".

## Weighted vectors
Calculates a weighted average of all vectors from the average (center) point to the gps points on the path:\
\
<img src="https://user-images.githubusercontent.com/57962936/115405333-71e42e80-a1ee-11eb-8937-439e753f6a5b.png" width=300>\
\
Then every vector is multiplied with it's weight (climb rate/absolute climb sum) where 'absolute climb sum' equals the sum of the absolute of all vario values. That results in this optimal point:\
\
<img src="https://user-images.githubusercontent.com/57962936/115410878-4d3e8580-a1f3-11eb-812f-87bdbb663b0b.png" width=400>

## Bias
This algorithm only adds a bias to all variometer values. The bias is the smallest climb rate, but never bigger than zero:\
\
<img src="https://user-images.githubusercontent.com/57962936/115411702-fdac8980-a1f3-11eb-8d7d-fe058b2f7a55.png" width=400>\
\
Resulting in this optimal point:\
\
<img src="https://user-images.githubusercontent.com/57962936/115411827-1c128500-a1f4-11eb-818d-bd7b54fc2b09.png" width=400>\
\
In this simple scenario the vector is a bit shorter, but hardly different from the one without bias. Regardless the bias obviously makes this "guess" worse.\
For legitimate use cases see the section 'Use cases' below.\
As a side-effect of this approach the recommended shifts often are less aggressive.

# Use cases
<p>
  <img src="https://user-images.githubusercontent.com/57962936/115416629-39e1e900-a1f8-11eb-9630-140859666782.png" width=300>
  <img src="https://user-images.githubusercontent.com/57962936/115416998-8a594680-a1f8-11eb-851a-9b29b73c071a.png" width=300>
</p>
&#8195;Case 1&#8195;&#8195;&#8195;&#8195;&#8195;&#8195;&#8195;&#8195;&#8195;&#8195;&#8195;&#8195;&#8195;&#8195;&#8195;&#8195;Case 2

### Best subsequence
This algorithm is ideal for early flights with punctual and inconsistent thermals (case 1) since it will always navigate the pilot to the border of the recorded circle.\
However once the thermals become wider, the app still recommends to shift the center point.\
For example in case 1 the best point would be the "2" in the top right corner, which clearly is the best option. In scenario 2 the "3" would be chosen, although it is obviously closer to falling air and worse than the middle of the right half.

### Weighted vectors
Wider thermals are where weighted vectors turn out to be better. Since the resulting points are averages, it's advantageous if there are distinct areas of better/worse climb rates. Also once the perfect spot is found, the app will basically recommend to stay there.\
In scenario 1 the calculated "best" point would be very close to the current center point. Though the app would recommend to move to the east in scenario 2 which is definitely the best choice.

### Bias
With bias enabled, even negative climb rates are still considered "positive" by how much better they are than the worst point.
Hence it is useful when the air does not go up anywhere and the pilot wants to stay airborne as long as possible.


# Math
![Screenshot_2021-04-20 StackEdit(2)](https://user-images.githubusercontent.com/57962936/115458458-061db800-a226-11eb-9292-44ab3dee70d3.png)
