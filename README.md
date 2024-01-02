# SteamID Utility Tool
This is a simple utility program for converting between different SteamID formats.

![SteamID utility program](https://github.com/xDahl/SteamID-Tool/blob/main/SteamIDProg.PNG?raw=true)
(Font: Comic Code)

## How the date estimations work:
Every SteamID contains a unique 32-bit number, I'll refer to them as 'AccountID'.\
While AccountIDs don't contain any creation dates in them, they are unique to each SteamID,\
and are incremented for each new SteamID made.

This means that a Steam account made in 2003 will have a low AccountID number,\
and newer accounts will have a higher AccountID number.

This program keeps a list of AccountIDs made on the first of each month since Steam went public,\
and by simply interpolating any AccountID between what is in the data-set;\
you can roughly estimate when an account was made.

---

# Limitations of date estimations:

## Accuracy:
While the dates are not 100% accurate, they're fairly close, often off by only a few days.\
That said, when I made this list of AccountIDs, I found that there were oddities in the data-set.\
This means that you _CAN_ get dates that are off by a month, it appears to be fairly rare, but it can happen.

## Keeping the data-set up to date:
It's important to note that we cannot 100% predict the next AccountID on the first the next month.\
This means that for newer accounts, the best we can do is _guess_ what the next AccountID will be\
based on previous data, and hope for the best.

The other con to using this, is that the data-set has to be updated each month with a new AccountID.\
This can be rather tedious, but it's doable.

Currently in this code, it only guesses the next AccountID for the next month,\
but there's nothing stopping us from guessing the next AccountIDs for the next few months.\
That would of course be less accurate, but could work if you wanted less updates.

## Inaccurate date calculations:
Lastly, calculating the actual creation date is inaccurate, as I went for a quick'n dirty way of calculating dates.\
My code does not take leap years into account, nor any other proper ways of calculating dates.\
I figured it didn't matter all that much, given the circumstances.

On the plus side, if you have a lot of SteamIDs you want to estiamte the dates of, it's very fast.

---

# Why bother with the date estimations?

Why did I bother making this when it's public info when accounts were made?\
Well, when people set their profiles to be private, that information often get hidden.\
With this feature, you can roughly estimate when the account was made.
