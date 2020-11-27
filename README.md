# Final-Project-2019

This repository contains the final project that Francesco Cabras and Antonia Donvito realized for the Statistical Learning course within the Master's programme in Data Science at the University of Trento. 
We trained several classification models on the Occupancy Detection Data Set, which provide data from light, temperature, humidity and CO2 sensors in a room, with the aim of predicting whether the room is occupied or not. The dataset is available at the following link: http://archive.ics.uci.edu/ml/datasets/Occupancy+Detection+ .
The repository contains:
- the analysis carried out in R;
- the final paper.
## Abstract
To make the world a better place, mankind should not only care about the way energy is produced but also, and especially, about how it is consumed. In the path to sustainability, the priority is to avoid any type of waste. If fifty years ago such optimization was somehow difficult to be obtained, now the affordability and the capabilities of sensors are making it within reach.\\
The aim of the authors is to demonstrate how easy it is to predict the presence of individuals in a room, specifically an office. This can help in a variety of ways: for instance the System could decide to automatically turn heaters and lights off.

## Models
After cleaning and preprocessing the data, we trained the following models:
- Logistic Regression
- Linear Discriminant Analysis
- Quadratic Discriminant Analysis
- K-Nearest Neighbours
- Support Vector Classifier
- Classification tree
- Random Forest

## Conclusion
As can be read in our paper, we found that the presence of people in the office can be inferred simply from the light level, as both classification tree and random forests reveal.
