module tpstv

pub struct Rule[S] {
	name        string [required]
	description string
	start       S      [required]
	end         S      [required]
	stimulus    string [required]
}

pub struct Protocol[T, S] {
	name        string   [required]
	description string
	rules []Rule[S] [required]
}
