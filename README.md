Codingame : Ocean of Code
Ravan Sadigli – 20160807005
1.	First of all, we have to move. And we want not to visit the position we have visited before. This means that we should avoid visiting the previous position. And our priority is going to N | S | E | W . Also, we cannot pass through an island. So, we need to know the location of the island (the islands are generated randomly and indicated by x).
2.	To damage the opponent, we need to predict the opponent's position. We predict the opponent moves and we record the opponent position. Then, we apply moves to a possible starting position.
3.	We need to fire to damage the opponent. We use torpedo for the fire to the opponent.


